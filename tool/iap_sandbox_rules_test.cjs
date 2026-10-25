// Rules check for config/iapSandbox (functions/apple_iap.js: uids whose
// Sandbox App Store purchases are credited) in firestore.rules, run against
// the Firestore emulator. Same setup as charm_board_rules_test.cjs:
//   firebase emulators:exec --only firestore --project demo-charm "node tool/iap_sandbox_rules_test.cjs"
// Nothing here touches the real project. The point: no client reads or
// writes the allowlist; only the Admin SDK / Firebase console does.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc,getDoc,updateDoc,deleteDoc} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-charm', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0, bad=0;
  const t = async (name, p, want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name, String(e.message).slice(0,120));} };
  const ADMIN = 'rFdE3O7LLBZIu0msxtvGktXmfJp1';
  const admin = env.authenticatedContext(ADMIN).firestore();
  const a = env.authenticatedContext('alice').firestore();
  const guest = env.unauthenticatedContext().firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(),'config','iapSandbox'), {allowUids:['reviewer']});
    await setDoc(doc(ctx.firestore(),'config','phaleShop'), {open:true});
  });
  const S = (db)=>doc(db,'config','iapSandbox');
  await t('alice cannot add herself to the allowlist', setDoc(S(a), {allowUids:['alice']}), false);
  await t('alice cannot update the allowlist', updateDoc(S(a), {allowUids:['reviewer','alice']}), false);
  await t('alice cannot delete the allowlist', deleteDoc(S(a)), false);
  await t('a guest cannot write the allowlist', setDoc(S(guest), {allowUids:['x']}), false);
  await t('alice cannot read the allowlist', getDoc(S(a)), false);
  await t('a guest cannot read the allowlist', getDoc(S(guest)), false);
  await t('admin reads the allowlist', getDoc(S(admin)));
  await t('admin cannot write it from the app (console / Admin SDK only)', setDoc(S(admin), {allowUids:['x']}), false);
  await t('other config docs stay public to read', getDoc(doc(guest,'config','phaleShop')));
  console.log(`\n${ok} passed, ${bad} failed`);
  await env.cleanup();
  process.exit(bad?1:0);
})();