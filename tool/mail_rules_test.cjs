// Rules check for the leaderboard reward mails (mails/bxh_{period}_{uid}) in firestore.rules,
// run against the Firestore emulator. Same setup as charm_board_rules_test.cjs:
//   firebase emulators:exec --only firestore --project demo-charm "node mail_rules_test.cjs"
// Nothing here touches the real project.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,deleteDoc,serverTimestamp} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const admin = env.authenticatedContext('rFdE3O7LLBZIu0msxtvGktXmfJp1').firestore();
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const reward = (uid, o={})=>({title:'Thưởng xếp hạng Mị lực', body:'Hạng 1 mùa season-1', target:uid,
    rewards:{items:[{kind:'phaLe',amount:100},{kind:'giotHoa',amount:20},{kind:'petItem',id:'mao_lua',amount:1}]},
    createdAt: serverTimestamp(), ...o});
  const M = (db,id)=>doc(db,'mails',id);
  const S = (db,uid,id)=>doc(db,'users',uid,'mailState',id);
  const id = 'bxh_season-1_alice';
  await t('admin creates the reward mail', setDoc(M(admin,id), reward('alice')));
  await t('admin cannot overwrite it (grants are written once)', setDoc(M(admin,id), reward('alice',{rewards:{items:[{kind:'phaLe',amount:5000}]}})), false);
  await t('a second approval of the same season is refused', setDoc(M(admin,id), reward('alice')), false);
  await t('an ordinary mail can still be edited', (async()=>{ await setDoc(M(admin,'hello'), reward('all')); await setDoc(M(admin,'hello'), reward('all',{title:'Edited'})); })());
  await t('a player cannot create a reward mail', setDoc(M(a,'bxh_season-1_alice2'), reward('alice')), false);
  await t('a player cannot edit a reward mail', setDoc(M(a,id), reward('alice',{title:'x'})), false);
  await t('alice reads her reward', getDoc(M(a,id)));
  await t('bob cannot read alice reward', getDoc(M(b,id)), false);
  await t('alice claims it', setDoc(S(a,'alice',id), {read:true, claimed:true, claimedAt: serverTimestamp()}));
  await t('alice cannot claim twice (mark never changes)', setDoc(S(a,'alice',id), {read:true, claimed:true, claimedAt: serverTimestamp()}), false);
  await t('bob cannot claim alice reward', setDoc(S(b,'bob',id), {read:true, claimed:true, claimedAt: serverTimestamp()}), false);
  await t('admin deletes a reward', deleteDoc(M(admin,id)));
  await t('admin re-sends the same id after a delete', setDoc(M(admin,id), reward('alice')));
  await t('the claimed mark survives the re-send', setDoc(S(a,'alice',id), {read:true, claimed:true, claimedAt: serverTimestamp()}), false);
  await t('item reward with 20 rows is allowed', setDoc(M(admin,'bxh_season-1_bob'), reward('bob',{rewards:{items:Array.from({length:20},()=>({kind:'phaLe',amount:1}))}})));
  await t('21 rows refused', setDoc(M(admin,'bxh_season-1_cara'), reward('cara',{rewards:{items:Array.from({length:21},()=>({kind:'phaLe',amount:1}))}})), false);
  await env.withSecurityRulesDisabled(async ctx=>{ await setDoc(doc(ctx.firestore(),'users','alice'), {progress:{day:5}}); await setDoc(doc(ctx.firestore(),'charm_board','season-1','entries','alice'), {uid:'alice'}); });
  await t('admin reads a player save (recompute check)', getDoc(doc(admin,'users','alice')));
  await t('a player cannot read another save', getDoc(doc(b,'users','alice')), false);
  await t('admin reads a board row', getDoc(doc(admin,'charm_board','season-1','entries','alice')));
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
