import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../logic/supporters.dart';

/// Public read of `supporters`. Sorting happens in [sortSupporters].
class FirestoreSupporterSource implements SupporterSource {
  const FirestoreSupporterSource();

  @override
  Future<List<Supporter>> load() async {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase chưa khởi tạo');
    }
    final snap = await FirebaseFirestore.instance
        .collection('supporters')
        .get();
    return [for (final doc in snap.docs) supporterFromDoc(doc.id, doc.data())];
  }
}

Supporter supporterFromDoc(String id, Map<String, dynamic> data) {
  final date = data['date'];
  return supporterFromFields(
    id: id,
    name: data['name'],
    message: data['message'],
    date: date is Timestamp ? date.toDate() : null,
    visible: data['visible'],
    avatar: data['avatar'],
    amount: data['amount'],
  );
}
