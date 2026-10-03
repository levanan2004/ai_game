import 'package:flutter/foundation.dart';

import 'mailbox.dart';
import 'notice_feed.dart';

/// Tabs of the Hộp thư popup.
enum InboxTab {
  /// Per-player mail, some with gifts to claim ([MailboxFeed]).
  mail,

  /// Shop-wide announcements, read only ([NoticeFeed]).
  news,
}

/// The Hộp thư popup: "Thư" and "Tin tức" under one frame.
///
/// Every way in goes through [openAt]: the shelf envelope opens on Thư,
/// the bell on Tin tức, and a later corner menu (Hộp thư, Phúc lợi) only
/// needs to call it too. The open flag and the open letter stay on [mail];
/// the open announcement stays on [news].
class Inbox extends ChangeNotifier {
  Inbox({required this.mail, this.news}) {
    mail.addListener(notifyListeners);
    news?.addListener(notifyListeners);
  }

  final MailboxFeed mail;

  /// Null hides the Tin tức tab.
  final NoticeFeed? news;

  var tab = InboxTab.mail;

  bool get open => mail.open;

  int get unreadMail => mail.unread;
  int get unreadNews => news?.unread ?? 0;

  /// Badge on the envelope: everything waiting in both tabs.
  int get unread => unreadMail + unreadNews;

  /// True while a letter or an announcement is open (back goes to its list).
  bool get inDetail => switch (tab) {
    InboxTab.mail => mail.detail != null,
    InboxTab.news => news?.detail != null,
  };

  /// Opens the popup on [to], at its list.
  void openAt(InboxTab to) {
    tab = news == null ? InboxTab.mail : to;
    news?.showList();
    if (mail.open) {
      mail.showList();
    } else {
      mail.toggle();
    }
    news?.refresh();
    notifyListeners();
  }

  void selectTab(InboxTab to) {
    if (news == null || tab == to) return;
    tab = to;
    mail.showList();
    news!.showList();
    notifyListeners();
  }

  /// Back arrow: an open letter or announcement goes back to its list;
  /// a list closes the popup.
  void back() {
    if (!inDetail) return close();
    switch (tab) {
      case InboxTab.mail:
        mail.showList();
      case InboxTab.news:
        news?.showList();
    }
  }

  void close() {
    news?.showList();
    mail.close();
  }

  @override
  void dispose() {
    mail.removeListener(notifyListeners);
    news?.removeListener(notifyListeners);
    super.dispose();
  }
}
