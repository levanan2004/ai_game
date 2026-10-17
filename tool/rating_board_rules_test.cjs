// Rules check for Bảng xếp hạng Đánh giá (rating_board, rating_state), run
// against the Firestore emulator:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/rating_board_rules_test.cjs"
// Nothing here touches the real project. The point: the app reads the board
// but can never write a score; the server counters are not readable.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,getDocs,updateDoc,deleteDoc,collection,query,orderBy,limit} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const a = env.authenticatedContext('alice').firestore();
  const guest = env.unauthenticatedContext().firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db,'rating_board','rating-2'), {totalV:60, totalSum:290, C:4});
    await setDoc(doc(db,'rating_board','rating-2','entries','alice'), {uid:'alice', v:60, sum:290, score:4.4, sortKey:44000060});
    await setDoc(doc(db,'rating_board','rating-2','entries','bob'), {uid:'bob', v:3, sum:15, score:4.03, sortKey:0});
    await setDoc(doc(db,'rating_state','alice'), {day:9, v:60});
  });
  const E = (db,id)=>doc(db,'rating_board','rating-2','entries',id);
  const top = (db,n)=>getDocs(query(collection(db,'rating_board','rating-2','entries'), orderBy('sortKey','desc'), limit(n)));
  await t('alice reads the top 100', top(a,100));
  await t('alice cannot list more than 100', top(a,101), false);
  await t('alice cannot list without a limit', getDocs(collection(a,'rating_board','rating-2','entries')), false);
  await t('alice reads her own row', getDoc(E(a,'alice')));
  await t('alice reads bob\'s row', getDoc(E(a,'bob')));
  await t('alice reads the season totals', getDoc(doc(a,'rating_board','rating-2')));
  await t('a guest cannot read the board', top(guest,10), false);
  await t('a guest cannot read a row', getDoc(E(guest,'alice')), false);
  await t('alice cannot raise her score', updateDoc(E(a,'alice'), {score:5, sortKey:50009999}), false);
  await t('alice cannot create a row', setDoc(E(a,'carol'), {uid:'carol', v:500, sum:2500}), false);
  await t('alice cannot write her own new row', setDoc(doc(a,'rating_board','rating-3','entries','alice'), {v:1}), false);
  await t('alice cannot delete bob\'s row', deleteDoc(E(a,'bob')), false);
  await t('alice cannot delete her row', deleteDoc(E(a,'alice')), false);
  await t('alice cannot change C', updateDoc(doc(a,'rating_board','rating-2'), {C:1}), false);
  await t('alice cannot read the server counters', getDoc(doc(a,'rating_state','alice')), false);
  await t('alice cannot reset the counters', setDoc(doc(a,'rating_state','alice'), {day:1}), false);
  // Season payout (functions/rating_payout.js): review lines, champion.
  const admin = env.authenticatedContext('rFdE3O7LLBZIu0msxtvGktXmfJp1').firestore();
  const RV = (db,id)=>doc(db,'rating_board','rating-2','review',id);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(RV(ctx.firestore(),'alice'), {status:'held', rank:1, flags:['new_account']});
  });
  await t('admin reads a review line', getDoc(RV(admin,'alice')));
  await t('admin lists the review lines', getDocs(collection(admin,'rating_board','rating-2','review')));
  await t('admin marks a held line released', setDoc(RV(admin,'alice'), {status:'released'}, {merge:true}));
  await t('alice cannot read her review line', getDoc(RV(a,'alice')), false);
  await t('alice cannot write a review line', setDoc(RV(a,'alice'), {status:'released'}, {merge:true}), false);
  await t('admin sets the champion', updateDoc(doc(admin,'rating_board','rating-2'), {champion:'alice'}));
  await t('admin cannot change C with the champion', updateDoc(doc(admin,'rating_board','rating-2'), {champion:'bob', C:1}), false);
  await t('admin cannot set an empty champion', updateDoc(doc(admin,'rating_board','rating-2'), {champion:''}), false);
  await t('admin cannot create a season doc', setDoc(doc(admin,'rating_board','rating-9'), {champion:'alice'}), false);
  await t('alice cannot make herself champion', updateDoc(doc(a,'rating_board','rating-2'), {champion:'alice'}), false);
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
