import '../data/phale_shop.dart';
import 'mailbox.dart';
import 'rewards.dart';
import 'shop_session.dart';

/// A paid top-up order: fetches the mail the server wrote
/// (`mails/phale_{orderId}`) and claims it through the normal gift mailbox,
/// which adds the Pha lê with `grantRewards(source: mailbox)`. The claimed
/// mark is flipped on the server first, so a retry, a second tab or a second
/// device cannot add it twice. Returns the new balance, or null when the mail
/// was not claimed (not visible yet, tab may not write): it stays in the
/// mailbox and the player claims it there.
Future<int?> claimPhaleMail(
  ShopSession session,
  MailboxFeed feed,
  PhaleOrder order,
) async {
  final id = order.mailId ?? 'phale_${order.orderId}';
  final uid = session.accountUid;
  if (uid == null) return null;
  if (feed.uid != uid) await feed.bindUser(uid);
  // The mail was written a moment ago; read the inbox again to see it.
  await feed.refresh();
  final result = await feed.claim(
    id,
    allowed: session.canWriteAccount && session.accountUid == feed.uid,
    grant: (m) => session.grantRewards(m.rewards, source: RewardSource.mailbox),
  );
  if (result == MailClaimResult.claimed || result == MailClaimResult.already) {
    return session.state.phaLe;
  }
  return null;
}