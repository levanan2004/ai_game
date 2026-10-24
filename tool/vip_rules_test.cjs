// Rules check for VIP (functions/vip.js), against the Firestore emulator:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/vip_rules_test.cjs"
// Nothing here touches the real project. The point: the tier (wallets/{uid}
// vip*, player_avatars/{uid}.vip / vipAt) and the Bảng vinh danh rows
// (vip_hall) are written only by the functions; the app can still change its
// portrait with a VIP tier on the doc.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,getDocs,updateDoc,deleteDoc,deleteField,collection,query,orderBy,limit} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const guest = env.unauthenticatedContext().firestore();
  const T = new Date('2026-10-17T03:00:00Z');
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db,'player_avatars','alice'), {path:'minh_anh', rev:1, frame:'vip_ngoc_luc_bao', frameAt:T, vip:10, vipAt:T});
    await setDoc(doc(db,'player_avatars','bob'), {path:'bear', rev:1, vip:2, vipAt:T});
    await setDoc(doc(db,'wallets','alice'), {phaLe:5, seededAt:T, vipLevel:10, vipVnd:15000000, vipGifted:{}});
    await setDoc(doc(db,'vip_hall','alice'), {at:T, name:'Tiệm Alice', avatar:'minh_anh', hidden:false});
  });
  const P = (db,id)=>doc(db,'player_avatars',id);
  const H = (db,id)=>doc(db,'vip_hall',id);
  const W = (db,id)=>doc(db,'wallets',id);

  // public tier
  await t('a guest reads a VIP tier on player_avatars', getDoc(P(guest,'alice')));
  await t('alice changes her portrait, VIP tier untouched (merge)', setDoc(P(a,'alice'), {path:'lan', rev:2}, {merge:true}));
  await t('bob changes his portrait (vip, no frame)', setDoc(P(b,'bob'), {path:'cat', rev:2}, {merge:true}));
  await t('bob cannot raise his tier', updateDoc(P(b,'bob'), {vip:10}), false);
  await t('bob cannot drop his tier field', updateDoc(P(b,'bob'), {vip:deleteField()}), false);
  await t('bob cannot drop vip with a full set', setDoc(P(b,'bob'), {path:'cat', rev:3}), false);
  await t('bob cannot move vipAt', updateDoc(P(b,'bob'), {vipAt:new Date()}), false);
  await t('carol cannot create a doc with a tier', setDoc(P(env.authenticatedContext('carol').firestore(),'carol'), {path:'mai', rev:1, vip:3}), false);
  await t('carol creates a plain portrait', setDoc(P(env.authenticatedContext('carol').firestore(),'carol'), {path:'mai', rev:1}));
  // wallet: owner reads, nobody writes
  await t('alice reads her wallet (vipLevel, vipVnd)', getDoc(W(a,'alice')));
  await t('bob cannot read alice\'s wallet (her amount)', getDoc(W(b,'alice')), false);
  await t('alice cannot write her vipLevel', updateDoc(W(a,'alice'), {vipLevel:10}), false);
  await t('alice cannot create a wallet with a tier', setDoc(W(b,'bob'), {vipLevel:5}), false);
  // the hall
  await t('a signed-in player reads the hall', getDocs(query(collection(b,'vip_hall'), orderBy('at'), limit(20))));
  await t('bob reads alice\'s hall row', getDoc(H(b,'alice')));
  await t('a guest cannot read the hall', getDoc(H(guest,'alice')), false);
  await t('bob cannot add himself to the hall', setDoc(H(b,'bob'), {at:T, name:'Bob', hidden:false}), false);
  await t('alice cannot hide herself by hand (callable only)', updateDoc(H(a,'alice'), {hidden:true}), false);
  await t('alice cannot delete her hall row', deleteDoc(H(a,'alice')), false);
  console.log(`ok ${ok} bad ${bad}`);
  await env.cleanup();
  process.exit(bad?1:0);
})();
