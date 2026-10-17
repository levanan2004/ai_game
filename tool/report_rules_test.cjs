// Rules check for profile reports (profile_reports/{reporterUid}_{targetUid}) in
// firestore.rules, run against the Firestore emulator. Same setup as
// charm_board_rules_test.cjs:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/report_rules_test.cjs"
// Nothing here touches the real project.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,getDocs,collection,deleteDoc,serverTimestamp} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const admin = env.authenticatedContext('rFdE3O7LLBZIu0msxtvGktXmfJp1').firestore();
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const guest = env.unauthenticatedContext().firestore();
  const R = (db,id)=>doc(db,'profile_reports',id);
  const report = (o={})=>({reporterUid:'alice', targetUid:'bob', targetName:'Tiệm Hoa Bob', reason:'profane',
    note:'', source:'charm_board', createdAt: serverTimestamp(), ...o});
  await t('a guest cannot report', setDoc(R(guest,'alice_bob'), report()), false);
  await t('alice cannot report as bob', setDoc(R(a,'bob_cara'), report({reporterUid:'bob', targetUid:'cara'})), false);
  await t('alice cannot report herself', setDoc(R(a,'alice_alice'), report({targetUid:'alice'})), false);
  await t('the id must be reporter_target', setDoc(R(a,'alice_cara'), report()), false);
  await t('an unknown reason is refused', setDoc(R(a,'alice_bob'), report({reason:'mean'})), false);
  await t('a note over 200 is refused', setDoc(R(a,'alice_bob'), report({note:'a'.repeat(201)})), false);
  await t('a name over 80 is refused', setDoc(R(a,'alice_bob'), report({targetName:'a'.repeat(81)})), false);
  await t('an extra field is refused', setDoc(R(a,'alice_bob'), report({email:'x@y.z'})), false);
  await t('a missing field is refused', setDoc(R(a,'alice_bob'), (({note, ...rest})=>rest)(report())), false);
  await t('another source is refused', setDoc(R(a,'alice_bob'), report({source:'chat'})), false);
  await t('a client time is refused', setDoc(R(a,'alice_bob'), report({createdAt:new Date()})), false);
  await t('alice reports bob (note of 200)', setDoc(R(a,'alice_bob'), report({note:'a'.repeat(200)})));
  await t('a second report of the same pair is refused', setDoc(R(a,'alice_bob'), report({reason:'spam'})), false);
  await t('alice cannot read her report back', getDoc(R(a,'alice_bob')), false);
  await t('bob cannot read it', getDoc(R(b,'alice_bob')), false);
  await t('players cannot list reports', getDocs(collection(a,'profile_reports')), false);
  await t('alice cannot delete it', deleteDoc(R(a,'alice_bob')), false);
  await t('admin reads it', getDoc(R(admin,'alice_bob')));
  await t('admin lists reports', getDocs(collection(admin,'profile_reports')));
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
