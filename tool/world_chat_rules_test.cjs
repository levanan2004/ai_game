// Rules check for Tin thế giới (world_chat, world_chat_meta, world_chat_state,
// chat_mutes, chat_reports, config/worldChat) in firestore.rules, run against
// the Firestore emulator. Same setup as charm_board_rules_test.cjs:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/world_chat_rules_test.cjs"
// Nothing here touches the real project. The point: no client can write a
// chat message; only functions/world_chat.js (Admin SDK) does.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,getDocs,updateDoc,deleteDoc,collection,query,orderBy,limit,serverTimestamp} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const ADMIN = 'rFdE3O7LLBZIu0msxtvGktXmfJp1';
  const admin = env.authenticatedContext(ADMIN).firestore();
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const guest = env.unauthenticatedContext().firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db,'world_chat','m0000000001'), {uid:'bob', name:'Tiệm Bob', avatar:'', text:'chào', seq:1, createdAt:new Date()});
    await setDoc(doc(db,'world_chat','m0000000002'), {uid:'alice', name:'Tiệm Alice', avatar:'', text:'hi', seq:2, createdAt:new Date()});
    await setDoc(doc(db,'world_chat_meta','state'), {seq:2});
    await setDoc(doc(db,'world_chat_state','alice'), {lastAt:new Date(), recent:[]});
    await setDoc(doc(db,'chat_reports','alice_m0000000001'), {reporterUid:'alice', targetUid:'bob', messageId:'m0000000001', status:'open'});
  });
  const M = (db,id)=>doc(db,'world_chat',id);
  const msg = (o={})=>({uid:'alice', name:'Tiệm Alice', avatar:'', text:'xin chào', seq:3, createdAt:serverTimestamp(), ...o});
  const newest = (db, n=100)=>getDocs(query(collection(db,'world_chat'), orderBy('seq','desc'), limit(n)));

  // messages: nobody but the server writes
  await t('alice cannot create a message', setDoc(M(a,'m0000000003'), msg()), false);
  await t('a guest cannot create a message', setDoc(M(guest,'m0000000003'), msg({uid:'x'})), false);
  await t('even an admin cannot create a message from the app', setDoc(M(admin,'m0000000003'), msg({uid:ADMIN})), false);
  await t('alice cannot edit her own message', updateDoc(M(a,'m0000000002'), {text:'đổi'}), false);
  await t('alice cannot edit bob\'s message', updateDoc(M(a,'m0000000001'), {text:'đổi'}), false);
  await t('alice cannot delete her own message', deleteDoc(M(a,'m0000000002')), false);
  await t('admin cannot edit a message', updateDoc(M(admin,'m0000000001'), {text:'x'}), false);
  // reading
  await t('a guest reads the newest 100', newest(guest));
  await t('alice reads the newest 100', newest(a));
  await t('a list without a limit is refused', getDocs(collection(a,'world_chat')), false);
  await t('a list of 101 is refused', newest(a, 101), false);
  await t('one message can be read', getDoc(M(b,'m0000000002')));
  // server-only docs
  await t('alice cannot read her cooldown', getDoc(doc(a,'world_chat_state','alice')), false);
  await t('alice cannot reset her cooldown', setDoc(doc(a,'world_chat_state','alice'), {lastAt:null}), false);
  await t('alice cannot delete her cooldown', deleteDoc(doc(a,'world_chat_state','alice')), false);
  await t('alice cannot move the counter', setDoc(doc(a,'world_chat_meta','state'), {seq:0}), false);
  await t('admin cannot touch the counter either', setDoc(doc(admin,'world_chat_meta','state'), {seq:0}), false);
  // reports: made by the callable only
  const report = {reporterUid:'bob', targetUid:'alice', messageId:'m0000000002', reason:'spam', note:'', status:'open'};
  await t('bob cannot write a report directly', setDoc(doc(b,'chat_reports','bob_m0000000002'), report), false);
  await t('alice cannot read her report', getDoc(doc(a,'chat_reports','alice_m0000000001')), false);
  await t('players cannot list reports', getDocs(collection(a,'chat_reports')), false);
  await t('admin lists reports', getDocs(collection(admin,'chat_reports')));
  await t('admin marks a report done', updateDoc(doc(admin,'chat_reports','alice_m0000000001'), {status:'done', handledBy:ADMIN, handledAt:serverTimestamp()}));
  await t('admin cannot rewrite the report text', updateDoc(doc(admin,'chat_reports','alice_m0000000001'), {text:'x'}), false);
  // mutes
  const mute = (o={})=>({level:'mute_1h', at:serverTimestamp(), by:ADMIN, reason:'Chửi bậy', messageId:'m0000000001', ...o});
  await t('alice cannot mute bob', setDoc(doc(a,'chat_mutes','bob'), mute({by:'alice'})), false);
  await t('bob cannot lift his own mute', setDoc(doc(b,'chat_mutes','bob'), mute({level:'warning', by:'bob'})), false);
  await t('admin mutes bob 1 hour', setDoc(doc(admin,'chat_mutes','bob'), mute()));
  await t('bob reads his own mute', getDoc(doc(b,'chat_mutes','bob')));
  await t('alice cannot read bob\'s mute', getDoc(doc(a,'chat_mutes','bob')), false);
  await t('bob cannot delete his mute', deleteDoc(doc(b,'chat_mutes','bob')), false);
  await t('an unknown level is refused', setDoc(doc(admin,'chat_mutes','bob'), mute({level:'mute_1y'})), false);
  await t('a client time is refused (the end comes from the server)', setDoc(doc(admin,'chat_mutes','bob'), mute({at:new Date(Date.now()-86400000)})), false);
  await t('an until field is refused', setDoc(doc(admin,'chat_mutes','bob'), mute({until:new Date(2100,0,1)})), false);
  await t('admin bans bob', setDoc(doc(admin,'chat_mutes','bob'), mute({level:'ban'})));
  await t('admin lifts it', deleteDoc(doc(admin,'chat_mutes','bob')));
  // kill switch
  await t('alice cannot switch the chat on', setDoc(doc(a,'config','worldChat'), {enabled:true}), false);
  await t('admin switches the chat on', setDoc(doc(admin,'config','worldChat'), {enabled:true, updatedAt:serverTimestamp()}));
  await t('the switch must be a bool', setDoc(doc(admin,'config','worldChat'), {enabled:'yes'}), false);
  await t('a guest reads the switch', getDoc(doc(guest,'config','worldChat')));
  // admin delete last
  await t('admin deletes a message', deleteDoc(M(admin,'m0000000001')));
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
