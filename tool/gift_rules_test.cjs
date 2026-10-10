// Admin gift rules (users/{uid}.gift) against the Firestore emulator; same setup as charm_board_rules_test.cjs.
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const {doc,setDoc} = require('firebase/firestore');
(async()=>{
  const env = await initializeTestEnvironment({projectId:'demo-gift', firestore:{rules: fs.readFileSync('firestore.rules','utf8'), host:'127.0.0.1', port:8085}});
  let ok=0,bad=0;
  const t = async (name,p,want=true)=>{ try{ await (want?assertSucceeds(p):assertFails(p)); ok++; console.log('PASS',name);}catch(e){bad++; console.log('FAIL',name,String(e.message).slice(0,100));} };
  const admin = env.authenticatedContext('rFdE3O7LLBZIu0msxtvGktXmfJp1').firestore();
  const other = env.authenticatedContext('mallory').firestore();
  const gift = (items)=>({gift:{id:'gift-0001-abcd',note:'',items}});
  await t('admin gives a pet item', setDoc(doc(admin,'users/u1'), gift({'item:mao_lua':1})));
  await t('admin gives 99 copies', setDoc(doc(admin,'users/u2'), gift({'item:canh_binh_minh':99})));
  await t('admin gives item + pha le + pot', setDoc(doc(admin,'users/u3'), gift({'item:chuong_ngoc':2,'pha_le':50,'dragon':1})));
  await t('100 copies refused', setDoc(doc(admin,'users/u4'), gift({'item:mao_lua':100})), false);
  await t('0 copies refused', setDoc(doc(admin,'users/u5'), gift({'item:mao_lua':0})), false);
  await t('unknown item refused', setDoc(doc(admin,'users/u6'), gift({'item:khong_co':1})), false);
  await t('a bare item id is not a gift key', setDoc(doc(admin,'users/u7'), gift({'mao_lua':1})), false);
  await t('a player cannot gift themselves', setDoc(doc(other,'users/mallory'), gift({'item:mao_lua':1})), false);
  await t('old pet gift still passes', setDoc(doc(admin,'users/u8'), gift({'pet:kim_long':1})));
  await t('old pot gift still passes', setDoc(doc(admin,'users/u9'), gift({'chau_song_ngu':3})));
  const many={}; ['dragon','phoenix','tiger','tortoise','qilin','nghe','crane','koi','chau_bach_duong','chau_kim_nguu','chau_song_tu','chau_cu_giai','chau_su_tu','chau_xu_nu','chau_thien_binh','chau_ho_cap','item:no_co_vai','item:vong_hoa_nho','item:chuong_ngoc','item:mu_rom','item:mao_lua','item:canh_buom','xu','pha_le'].forEach(k=>many[k]=1);
  await t('24 kinds in one gift (the most) stays inside the rules budget', setDoc(doc(admin,'users/u10'), gift(many)));
  await t('25 kinds refused', setDoc(doc(admin,'users/u11'), gift({...many,'banh_mat':1})), false);
  console.log('ok',ok,'bad',bad);
  await env.cleanup(); process.exit(bad?1:0);
})();
