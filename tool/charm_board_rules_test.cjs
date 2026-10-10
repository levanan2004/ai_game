// Rules check for the charm_board block of firestore.rules, run against the Firestore emulator.
// Needs JDK 21+, firebase-tools, @firebase/rules-unit-testing and firebase installed beside it,
// a firebase.json with the firestore rules + emulator on 127.0.0.1:8085. From that folder:
//   firebase emulators:exec --only firestore --project demo-charm "node charm_board_rules_test.cjs"
// Nothing here touches the real project.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,getDocs,deleteDoc,collection,query,orderBy,limit,serverTimestamp,Timestamp} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const anon = env.unauthenticatedContext().firestore();
  const row = (uid,o={})=>({uid, displayName:'Hoa', avatar:'', charm:120, updatedAt: serverTimestamp(), ...o});
  const P = (db,uid,per='season-1')=>doc(db,'charm_board',per,'entries',uid);
  await t('alice creates own row', setDoc(P(a,'alice'), row('alice')));
  await t('bob cannot write alice row', setDoc(P(b,'alice'), row('alice')), false);
  await t('alice cannot write bob row', setDoc(P(a,'bob'), row('bob')), false);
  await t('uid field must match', setDoc(P(b,'bob'), row('alice')), false);
  await t('charm over cap', setDoc(P(b,'bob'), row('bob',{charm:2001})), false);
  await t('charm at cap', setDoc(P(b,'bob'), row('bob',{charm:2000})));
  await t('negative charm', setDoc(P(a,'alice','season-2'), row('alice',{charm:-1})), false);
  await t('float charm', setDoc(P(a,'alice','season-2'), row('alice',{charm:1.5})), false);
  await t('extra field', setDoc(P(a,'alice','season-2'), row('alice',{extra:1})), false);
  await t('missing updatedAt', setDoc(P(a,'alice','season-2'), {uid:'alice',displayName:'x',avatar:'',charm:1}), false);
  await t('client-chosen updatedAt', setDoc(P(a,'alice','season-2'), row('alice',{updatedAt:Timestamp.now()})), false);
  await t('empty name', setDoc(P(a,'alice','season-2'), row('alice',{displayName:''})), false);
  await t('81-char name', setDoc(P(a,'alice','season-2'), row('alice',{displayName:'x'.repeat(81)})), false);
  await t('bad period key', setDoc(P(a,'alice','Bad Key'), row('alice')), false);
  await t('update too soon refused', setDoc(P(a,'alice'), row('alice',{charm:130})), false);
  await env.withSecurityRulesDisabled(async ctx=>{ await setDoc(P(ctx.firestore(),'carol'), row('carol',{charm:50, updatedAt: Timestamp.fromMillis(Date.now()-120000)})); });
  const c = env.authenticatedContext('carol').firestore();
  await t('update after 30s ok', setDoc(P(c,'carol'), row('carol',{charm:60})));
  await t('signed-in get', getDoc(P(b,'alice')));
  await t('anon get refused', getDoc(P(anon,'alice')), false);
  const col = (db)=>collection(db,'charm_board','season-1','entries');
  await t('top 100 list', getDocs(query(col(b), orderBy('charm','desc'), limit(100))));
  await t('limit 101 refused', getDocs(query(col(b), orderBy('charm','desc'), limit(101))), false);
  await t('no limit refused', getDocs(query(col(b), orderBy('charm','desc'))), false);
  await t('anon list refused', getDocs(query(col(anon), orderBy('charm','desc'), limit(10))), false);
  await t('bob cannot delete alice', deleteDoc(P(b,'alice')), false);
  await t('alice deletes own', deleteDoc(P(a,'alice')));
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
