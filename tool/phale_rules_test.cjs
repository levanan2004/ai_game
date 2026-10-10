// Rules check for the Pha lê top-up (phale_orders, phale_pending, sepay_txns,
// mails/phale_*, config/phaleShop), run against the Firestore emulator:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/phale_rules_test.cjs"
// (needs @firebase/rules-unit-testing and firebase on NODE_PATH, same as the
// other tool/*_rules_test.cjs). Nothing here touches the real project.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,getDocs,collection,updateDoc,deleteDoc,serverTimestamp,Timestamp} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const admin = env.authenticatedContext('rFdE3O7LLBZIu0msxtvGktXmfJp1').firestore();
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const anon = env.unauthenticatedContext().firestore();
  const code = 'THSMK7P2Q9XABC';
  await env.withSecurityRulesDisabled(async ctx=>{
    const db = ctx.firestore();
    await setDoc(doc(db,'phale_orders',code), {uid:'alice', packId:'pack_50k', amount:50000, status:'pending', transferContent:code});
    await setDoc(doc(db,'phale_pending','alice'), {orderId:code});
    await setDoc(doc(db,'sepay_txns','ipn_1'), {result:'credited'});
  });
  const O = (db)=>doc(db,'phale_orders',code);
  await t('alice reads her own order', getDoc(O(a)));
  await t('bob cannot read alice order', getDoc(O(b)), false);
  await t('signed-out cannot read an order', getDoc(O(anon)), false);
  await t('alice cannot list orders', getDocs(collection(a,'phale_orders')), false);
  await t('admin lists orders (resolve lech_goi)', getDocs(collection(admin,'phale_orders')));
  await t('alice cannot mark her order paid', updateDoc(O(a), {status:'paid', crystalsGranted:6250}), false);
  await t('alice cannot create an order', setDoc(doc(a,'phale_orders','THSMAAAAAAAAAA'), {uid:'alice', status:'paid', amount:500000}), false);
  await t('alice cannot delete her order', deleteDoc(O(a)), false);
  await t('even the admin client cannot write orders (Functions only)', updateDoc(O(admin), {status:'paid'}), false);
  await t('alice cannot read the pending pointer', getDoc(doc(a,'phale_pending','alice')), false);
  await t('alice cannot write the pending pointer', setDoc(doc(a,'phale_pending','alice'), {orderId:'x'}), false);
  await t('admin reads the pending pointer', getDoc(doc(admin,'phale_pending','alice')));
  await t('alice cannot read the SePay log', getDoc(doc(a,'sepay_txns','ipn_1')), false);
  await t('alice cannot forge a SePay log row', setDoc(doc(a,'sepay_txns','ipn_2'), {result:'credited'}), false);
  await t('admin reads the SePay log', getDoc(doc(admin,'sepay_txns','ipn_1')));
  const credit = (uid)=>({title:'Nap Pha le', body:'ok', target:uid, rewards:{items:[{kind:'phaLe',amount:6250}]}, createdAt: serverTimestamp()});
  await t('alice cannot create a phale_ credit mail', setDoc(doc(a,'mails','phale_'+code), credit('alice')), false);
  await t('admin client creates a phale_ mail (Functions use the Admin SDK)', setDoc(doc(admin,'mails','phale_'+code), credit('alice')));
  await t('a phale_ mail is never edited', setDoc(doc(admin,'mails','phale_'+code), credit('alice')), false);
  await t('alice reads her credit mail', getDoc(doc(a,'mails','phale_'+code)));
  await t('bob cannot read it', getDoc(doc(b,'mails','phale_'+code)), false);
  await t('alice claims it (like any reward)', setDoc(doc(a,'users','alice','mailState','phale_'+code), {read:true, claimed:true, claimedAt: serverTimestamp()}));
  await t('alice cannot claim twice', setDoc(doc(a,'users','alice','mailState','phale_'+code), {read:true, claimed:true, claimedAt: serverTimestamp()}), false);
  await t('bob cannot claim alice credit', setDoc(doc(b,'users','bob','mailState','phale_'+code), {read:true, claimed:true, claimedAt: serverTimestamp()}), false);
  await t('admin turns the shop on', setDoc(doc(admin,'config','phaleShop'), {open:true, updatedAt: serverTimestamp()}));
  await t('open must be a bool', setDoc(doc(admin,'config','phaleShop'), {open:'yes'}), false);
  await t('extra keys refused', setDoc(doc(admin,'config','phaleShop'), {open:true, packs:[]}), false);
  await t('a player cannot flip it', setDoc(doc(a,'config','phaleShop'), {open:true}), false);
  await t('anyone can read it', getDoc(doc(anon,'config','phaleShop')));
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();