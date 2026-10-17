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
    await setDoc(doc(db,'player_avatars','alice'), {path:'minh_anh', rev:1, frame:'la_non', frameAt:T, chatFrame:'chat_vip_bac', chatFrameBase:'chat_vip_bac', chatFrameAt:T});
    await setDoc(doc(db,'player_avatars','bob'), {path:'bear', rev:1});
    await setDoc(doc(db,'public_profiles','alice'), {day:37, updatedAt:T});
    await setDoc(doc(db,'admins','carol'), {at:T});
    await setDoc(doc(db,'titles','de_nhat_goi_hoa'), {titleId:'de_nhat_goi_hoa', holderUid:'alice', period:'rating-2', since:T});
    await setDoc(doc(db,'milestone_state','alice'), {day:9, sold:300, counted:300, note:''});
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
  // the chat frame (functions/chat_frames.js): never from the app
  await t('alice keeps her chat frame on a portrait change (merge)', setDoc(P(a,'alice'), {path:'hoa', rev:4}, {merge:true}));
  await t('alice cannot pick a chat frame', updateDoc(P(a,'alice'), {chatFrame:'chat_de_nhat_goi_hoa'}), false);
  await t('alice cannot move her chat frame base', updateDoc(P(a,'alice'), {chatFrameBase:'chat_vip_ngoc'}), false);
  await t('alice cannot clear the lost-title note', updateDoc(P(a,'alice'), {chatFrameLost:'x'}), false);
  await t('alice cannot move chatFrameAt', updateDoc(P(a,'alice'), {chatFrameAt:new Date()}), false);
  await t('bob cannot give himself a chat frame', setDoc(P(b,'bob'), {path:'cat', rev:4, chatFrame:'chat_vip_ngoc'}, {merge:true}), false);
  // public_profiles: read signed-in, write server only
  await t('bob reads alice\'s public profile', getDoc(doc(b,'public_profiles','alice')));
  await t('a guest cannot read public profiles', getDoc(doc(guest,'public_profiles','alice')), false);
  await t('alice cannot write her day', setDoc(doc(a,'public_profiles','alice'), {day:999}), false);
  await t('alice cannot delete her public profile', deleteDoc(doc(a,'public_profiles','alice')), false);
  // Champion titles (functions/titles.js): read signed-in, nobody writes.
  await t('bob reads who holds a title', getDoc(doc(b,'titles','de_nhat_goi_hoa')));
  await t('a guest cannot read titles', getDoc(doc(guest,'titles','de_nhat_goi_hoa')), false);
  await t('bob cannot take the title', setDoc(doc(b,'titles','de_nhat_goi_hoa'), {holderUid:'bob'}, {merge:true}), false);
  await t('an admin cannot move the title from the app', setDoc(doc(c,'titles','de_nhat_goi_hoa'), {holderUid:'carol'}, {merge:true}), false);
  await t('alice cannot delete her title', deleteDoc(doc(a,'titles','de_nhat_goi_hoa')), false);
  await t('bob cannot create a title', setDoc(doc(b,'titles','mi_luc_nhat_troi'), {holderUid:'bob'}), false);
  await t('alice cannot pin from the app', setDoc(doc(a,'public_profiles','alice'), {pinnedTitle:'de_nhat_goi_hoa'}, {merge:true}), false);
  await t('alice cannot raise her title count', setDoc(doc(a,'public_profiles','alice'), {titleStats:{de_nhat_goi_hoa:{timesWon:9}}}, {merge:true}), false);
  await t('an admin cannot write titleStats or bestRank', setDoc(doc(c,'public_profiles','bob'), {bestRank:{charm:{rank:1}}}, {merge:true}), false);
  // milestone counter (functions/milestones.js)
  await t('alice reads her milestone counter', getDoc(doc(a,'milestone_state','alice')));
  await t('bob cannot read alice milestone counter', getDoc(doc(b,'milestone_state','alice')), false);
  await t('alice cannot raise her counter', setDoc(doc(a,'milestone_state','alice'), {counted:99999}, {merge:true}), false);
  await t('alice cannot create a counter', setDoc(doc(a,'milestone_state','alice2'), {counted:1}), false);
  await t('an admin cannot write a counter', setDoc(doc(c,'milestone_state','alice'), {counted:1}, {merge:true}), false);
  await t('alice cannot give herself a milestone title', setDoc(doc(a,'public_profiles','alice'), {customers:100000, titleStats:{title_khach_100k:{permanent:true}}}, {merge:true}), false);
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
