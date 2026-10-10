// Rules check for the season end of the Mị lực board (charm_board/{period}
// meta doc: endsAt + 5 minute grace) and the payout bookkeeping docs, run
// against the Firestore emulator. Same harness as charm_board_rules_test.cjs:
//   firebase emulators:exec --only firestore --project demo-charm "node charm_season_rules_test.cjs"
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,deleteDoc,serverTimestamp,Timestamp} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const a = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const carol = env.authenticatedContext('carol').firestore();
  const admin = env.authenticatedContext('rFdE3O7LLBZIu0msxtvGktXmfJp1').firestore();
  const anon = env.unauthenticatedContext().firestore();
  const min = (m)=>Timestamp.fromMillis(Date.now()+m*60000);
  const row = (uid,o={})=>({uid, displayName:'Hoa', avatar:'', charm:120, petId:'meo', stage:1, worn:{neck:'no_co_vai'}, updatedAt: serverTimestamp(), reachedAt: serverTimestamp(), ...o});
  const P = (db,uid,per)=>doc(db,'charm_board',per,'entries',uid);
  const M = (db,per)=>doc(db,'charm_board',per);
  // Seed meta docs (no rules) and an old row per period for the update/delete cases.
  const old = Timestamp.fromMillis(Date.now()-120000);
  await env.withSecurityRulesDisabled(async ctx=>{
    const f = ctx.firestore();
    const metas = {'s-open': {endsAt:min(60)}, 's-grace': {endsAt:min(-2)}, 's-edge': {endsAt:min(-4.5)}, 's-late': {endsAt:min(-6)}, 's-noend': {startsAt:min(-600)}};
    for (const [per,m] of Object.entries(metas)) {
      await setDoc(M(f,per), m);
      await setDoc(P(f,'alice',per), row('alice',{charm:50, updatedAt: old, reachedAt: old}));
    }
    await setDoc(P(f,'alice','s-nometa'), row('alice',{charm:50, updatedAt: old, reachedAt: old}));
  });
  // before the end
  await t('create before the end', setDoc(P(bob,'bob','s-open'), row('bob')));
  await t('update before the end', setDoc(P(a,'alice','s-open'), row('alice',{charm:60})));
  await t('delete before the end', deleteDoc(P(a,'alice','s-open')));
  // inside the 5 minute grace
  await t('create 2 min after the end (grace)', setDoc(P(bob,'bob','s-grace'), row('bob')));
  await t('update 2 min after the end (grace)', setDoc(P(a,'alice','s-grace'), row('alice',{charm:60})));
  await t('update 4.5 min after the end (still grace)', setDoc(P(a,'alice','s-edge'), row('alice',{charm:60})));
  // after the grace
  await t('create 6 min after the end refused', setDoc(P(bob,'bob','s-late'), row('bob')), false);
  await t('update 6 min after the end refused', setDoc(P(a,'alice','s-late'), row('alice',{charm:60})), false);
  await t('delete 6 min after the end refused (board is frozen)', deleteDoc(P(a,'alice','s-late')), false);
  // wrong period: an ended season does not close another one
  await t('write to the open season while another is over', setDoc(P(carol,'carol','s-open'), row('carol')));
  await t('write to the over season still refused', setDoc(P(carol,'carol','s-late'), row('carol')), false);
  // missing meta: open (documented)
  await t('no meta doc: the period stays open', setDoc(P(a,'alice','s-nometa'), row('alice',{charm:60})));
  await t('meta without endsAt: the period stays open', setDoc(P(bob,'bob','s-noend'), row('bob')));
  await t('a player cannot create the meta doc', setDoc(M(a,'s-new'), {endsAt:min(10)}), false);
  await t('a player cannot extend endsAt', setDoc(M(a,'s-late'), {endsAt:min(9999)}), false);
  await t('anon cannot read meta', getDoc(M(anon,'s-open')), false);
  await t('a player reads meta', getDoc(M(a,'s-open')));
  // admin sets / edits the meta
  await t('admin creates meta', setDoc(M(admin,'s-new'), {startsAt:min(-5), endsAt:min(10), createdBy:'admin', createdAt:serverTimestamp()}));
  await t('admin edits endsAt of an ended season (reopens it)', setDoc(M(admin,'s-late'), {endsAt:min(60)}, {merge:true}));
  await t('after the edit the player can write again', setDoc(P(carol,'carol','s-late'), row('carol')));
  await t('meta needs a timestamp endsAt', setDoc(M(admin,'s-bad'), {endsAt:'2026-11-09'}), false);
  await t('meta refuses unknown fields', setDoc(M(admin,'s-bad'), {endsAt:min(1), hacked:1}), false);
  await t('admin deletes meta', deleteDoc(M(admin,'s-new')));
  // review docs
  await t('admin writes a review line', setDoc(doc(admin,'charm_board','s-late','review','alice'), {uid:'alice', rank:1, status:'held'}));
  await t('admin reads a review line', getDoc(doc(admin,'charm_board','s-late','review','alice')));
  await t('player cannot read review', getDoc(doc(a,'charm_board','s-late','review','alice')), false);
  await t('player cannot write review', setDoc(doc(a,'charm_board','s-late','review','alice'), {uid:'alice', status:'sent'}), false);
  // kill switch
  await t('admin writes the kill switch', setDoc(doc(admin,'config','charmPayout'), {autoPayout:false, updatedAt:serverTimestamp()}));
  await t('kill switch must be a bool', setDoc(doc(admin,'config','charmPayout'), {autoPayout:'no'}), false);
  await t('kill switch refuses other keys', setDoc(doc(admin,'config','charmPayout'), {autoPayout:true, x:1}), false);
  await t('player cannot write the kill switch', setDoc(doc(a,'config','charmPayout'), {autoPayout:true}), false);
  await t('anyone reads the config doc', getDoc(doc(anon,'config','charmPayout')));
  // players cannot write bxh_ mails
  const mail = {title:'Thưởng', body:'x', target:'alice', rewards:{items:[]}, createdAt:serverTimestamp()};
  await t('player cannot create a bxh_ mail', setDoc(doc(a,'mails','bxh_s-open_alice'), mail), false);
  await t('admin creates a bxh_ mail', setDoc(doc(admin,'mails','bxh_s-open_alice'), mail));
  await t('admin cannot edit a bxh_ mail', setDoc(doc(admin,'mails','bxh_s-open_alice'), {...mail, title:'Khác'}), false);
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();