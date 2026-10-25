// Rules check for player_prefs/{uid} (block list + chat "rules accepted",
// lib/logic/account_prefs.dart), run against the Firestore emulator:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/account_prefs_rules_test.cjs"
// Nothing here touches the real project. The point: only the owner reads or
// writes their prefs, with the three fields and at most 500 blocked.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,serverTimestamp} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const guest = env.unauthenticatedContext().firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(),'player_prefs','bob'), {blocked:{alice:'Tiệm Alice'}, chatRulesV1:true, updatedAt:new Date()});
  });
  const P = (db,id)=>doc(db,'player_prefs',id);
  const good = (blocked={}) => ({blocked, chatRulesV1:false, updatedAt:serverTimestamp()});
  const many = (n) => Object.fromEntries(Array.from({length:n}, (_,i)=>[`u${i}`, `Tiệm ${i}`]));

  await t('alice creates her prefs (first sign-in migration)', setDoc(P(a,'alice'), {blocked:{bob:'Tiệm Bob'}, chatRulesV1:true, updatedAt:serverTimestamp()}));
  await t('alice reads her prefs', getDoc(P(a,'alice')));
  await t('alice rewrites her list (unblock)', setDoc(P(a,'alice'), good()));
  await t('alice blocks 500 players', setDoc(P(a,'alice'), good(many(500))));
  await t('alice cannot block 501', setDoc(P(a,'alice'), good(many(501))), false);
  await t('bob cannot read alice\'s prefs', getDoc(P(b,'alice')), false);
  await t('a guest cannot read prefs', getDoc(P(guest,'bob')), false);
  await t('alice cannot read bob\'s list', getDoc(P(a,'bob')), false);
  await t('alice cannot write bob\'s list', setDoc(P(a,'bob'), good()), false);
  await t('a guest cannot write', setDoc(P(guest,'alice'), good()), false);
  await t('no other field', setDoc(P(a,'alice'), {...good(), vip:3}), false);
  await t('all three fields are needed', setDoc(P(a,'alice'), {blocked:{}, updatedAt:serverTimestamp()}), false);
  await t('blocked must be a map', setDoc(P(a,'alice'), {blocked:['bob'], chatRulesV1:false, updatedAt:serverTimestamp()}), false);
  await t('chatRulesV1 must be a bool', setDoc(P(a,'alice'), {blocked:{}, chatRulesV1:'yes', updatedAt:serverTimestamp()}), false);
  await t('updatedAt must be the server time', setDoc(P(a,'alice'), {blocked:{}, chatRulesV1:false, updatedAt:new Date('2020-01-01')}), false);
  await t('a partial update keeping the rules passes', updateDoc(P(a,'alice'), {chatRulesV1:true, updatedAt:serverTimestamp()}));
  await t('bob cannot delete alice\'s prefs', deleteDoc(P(b,'alice')), false);
  await t('alice deletes her prefs', deleteDoc(P(a,'alice')));
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
