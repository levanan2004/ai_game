// Rules check for khung avatar (player_avatars/{uid}.frame) and the profile
// card's public_profiles/{uid}, run against the Firestore emulator. Same setup
// as charm_board_rules_test.cjs:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/avatar_frames_rules_test.cjs"
// Nothing here touches the real project. The point: the app can change its
// portrait but never the frame; only functions/avatar_frames.js (Admin SDK)
// writes it, after checking ownership.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,deleteField} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const c = env.authenticatedContext('carol').firestore();
  const guest = env.unauthenticatedContext().firestore();
  const T = new Date('2026-10-17T03:00:00Z');
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db,'player_avatars','alice'), {path:'minh_anh', rev:1, frame:'la_non', frameAt:T});
    await setDoc(doc(db,'player_avatars','bob'), {path:'bear', rev:1});
    await setDoc(doc(db,'public_profiles','alice'), {day:37, updatedAt:T});
  });
  const P = (db,id)=>doc(db,'player_avatars',id);

  // reading
  await t('a guest reads a portrait and its frame', getDoc(P(guest,'alice')));
  await t('bob reads alice\'s frame', getDoc(P(b,'alice')));
  // the portrait still works
  await t('alice changes her portrait, frame untouched (merge)', setDoc(P(a,'alice'), {path:'lan', rev:2}, {merge:true}));
  await t('bob changes his portrait (no frame yet)', setDoc(P(b,'bob'), {path:'cat', rev:2}));
  await t('carol creates her first portrait', setDoc(P(c,'carol'), {path:'mai', rev:1}));
  // the frame: never from the app
  await t('alice cannot pick another frame', updateDoc(P(a,'alice'), {frame:'vip_ngoc_luc_bao'}), false);
  await t('alice cannot take her frame off herself', updateDoc(P(a,'alice'), {frame:deleteField()}), false);
  await t('alice cannot drop the frame with a full set', setDoc(P(a,'alice'), {path:'lan', rev:3}), false);
  await t('alice cannot move frameAt', updateDoc(P(a,'alice'), {frameAt:new Date()}), false);
  await t('bob cannot give himself a frame', setDoc(P(b,'bob'), {path:'cat', rev:3, frame:'vip_vang'}, {merge:true}), false);
  await t('carol cannot create with a frame', setDoc(P(c,'dave'), {path:'x', rev:1, frame:'la_non'}), false);
  await t('a new player cannot start with a frame', setDoc(doc(env.authenticatedContext('erin').firestore(),'player_avatars','erin'), {path:'x', rev:1, frame:'la_non'}), false);
  await t('bob cannot write alice\'s doc', setDoc(P(b,'alice'), {path:'x', rev:9}, {merge:true}), false);
  await t('alice cannot delete her doc', deleteDoc(P(a,'alice')), false);
  await t('no other field', setDoc(P(a,'alice'), {vip:10}, {merge:true}), false);
  // public_profiles: read signed-in, write server only
  await t('bob reads alice\'s public profile', getDoc(doc(b,'public_profiles','alice')));
  await t('a guest cannot read public profiles', getDoc(doc(guest,'public_profiles','alice')), false);
  await t('alice cannot write her day', setDoc(doc(a,'public_profiles','alice'), {day:999}), false);
  await t('alice cannot delete her public profile', deleteDoc(doc(a,'public_profiles','alice')), false);
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
