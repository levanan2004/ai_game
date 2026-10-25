// Rules check for the server wallet (wallets/{uid}: Pha lê balance, Thẻ gacha,
// pity counters, ledger) and walletClaim mails, against the Firestore emulator:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/wallet_rules_test.cjs"
// (needs @firebase/rules-unit-testing and firebase on NODE_PATH, same as the
// other tool/*_rules_test.cjs). Nothing here touches the real project.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,getDocs,collection,updateDoc,deleteDoc,serverTimestamp} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const admin = env.authenticatedContext('rFdE3O7LLBZIu0msxtvGktXmfJp1').firestore();
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const anon = env.unauthenticatedContext().firestore();
  const wallet = {phaLe: 120, cards: {chau_cuu_vi_ho: 3}, pity: {chau_cuu_vi_ho: {n: 40, week: 0}}, xuCards: {day: 20743, n: 2}};
  await env.withSecurityRulesDisabled(async ctx=>{
    const db = ctx.firestore();
    await setDoc(doc(db,'wallets','alice'), wallet);
    await setDoc(doc(db,'wallets','alice','ledger','r1'), {type:'buy', phaLe:-20});
    await setDoc(doc(db,'mails','phale_W1'), {title:'Nap', body:'', target:'alice', walletClaim:true, rewards:{items:[{kind:'phaLe',amount:500}]}, createdAt: new Date()});
    await setDoc(doc(db,'mails','gacha_alice_1'), {title:'Vong quay tuan', body:'', target:'alice', rewards:{items:[{kind:'coins',amount:200000}]}, createdAt: new Date()});
  });
  const W = (db, uid='alice')=>doc(db,'wallets',uid);
  await t('alice reads her wallet', getDoc(W(a)));
  await t('bob cannot read alice wallet', getDoc(W(b)), false);
  await t('signed-out cannot read a wallet', getDoc(W(anon)), false);
  await t('nobody lists wallets', getDocs(collection(a,'wallets')), false);
  await t('alice cannot raise her Pha lê', updateDoc(W(a), {phaLe: 99999}), false);
  await t('alice cannot add cards', updateDoc(W(a), {'cards.chau_cuu_vi_ho': 90}), false);
  await t('alice cannot set a pity counter', updateDoc(W(a), {'pity.chau_cuu_vi_ho': {n: 89, week: 0}}), false);
  await t('alice cannot reset the xu-card count of the day', updateDoc(W(a), {xuCards: {day: 20743, n: 0}}), false);
  await t('alice cannot replace her wallet', setDoc(W(a), {...wallet, phaLe: 5000}), false);
  await t('alice cannot delete her wallet', deleteDoc(W(a)), false);
  await t('bob cannot create a wallet', setDoc(W(b,'bob'), {phaLe: 100}), false);
  await t('even the admin client cannot write a wallet (Functions only)', updateDoc(W(admin), {phaLe: 1}), false);
  await t('alice reads her ledger', getDocs(collection(a,'wallets','alice','ledger')));
  await t('bob cannot read alice ledger', getDocs(collection(b,'wallets','alice','ledger')), false);
  await t('alice cannot write a ledger row', setDoc(doc(a,'wallets','alice','ledger','x'), {type:'earn', phaLe: 500}), false);
  const claim = {read:true, claimed:true, claimedAt: serverTimestamp()};
  await t('alice cannot claim a walletClaim mail herself', setDoc(doc(a,'users','alice','mailState','phale_W1'), claim), false);
  await t('alice may still mark it read', setDoc(doc(a,'users','alice','mailState','phale_W1'), {read:true, claimed:false, readAt: serverTimestamp()}));
  await t('alice claims a gacha reward mail (no Pha lê) like any gift', setDoc(doc(a,'users','alice','mailState','gacha_alice_1'), claim));
  await t('a gacha_ mail is never edited', setDoc(doc(admin,'mails','gacha_alice_1'), {title:'x', body:'', target:'alice', rewards:{items:[]}, createdAt: serverTimestamp()}), false);
  const mail = (extra)=>({title:'Qua', body:'', target:'alice', rewards:{items:[{kind:'phaLe',amount:5}]}, createdAt: serverTimestamp(), ...extra});
  await t('admin sends a mail with walletClaim true', setDoc(doc(admin,'mails','m_ok'), mail({walletClaim:true})));
  await t('walletClaim must be a bool', setDoc(doc(admin,'mails','m_bad'), mail({walletClaim:'yes'})), false);
  await t('alice cannot send mails', setDoc(doc(a,'mails','m_alice'), mail({})), false);
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
