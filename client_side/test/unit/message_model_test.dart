import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/models/message.dart';

void main() {
  group('MessageModel Tests', () {
    test('Should correctly parse from JSON', () {
      final json = {
        '_id': 'msg_123',
        'sender': {
          '_id': 'user_1',
          'displayName': 'John Doe',
          'username': 'johndoe'
        },
        'text': 'Hello world',
        'imageUrl': '',
        'status': 'seen',
        'createdAt': '2024-03-20T10:00:00.000Z',
        'isPinned': true
      };

      final message = MessageModel.fromJson(json);

      expect(message.id, 'msg_123');
      expect(message.senderId, 'user_1');
      expect(message.senderName, 'John Doe');
      expect(message.text, 'Hello world');
      expect(message.isPinned, true);
    });

    test('Should handle missing sender object', () {
      final json = {
        '_id': 'msg_123',
        'sender': 'user_1',
        'text': 'Hello world',
        'imageUrl': '',
        'status': 'sent',
        'createdAt': '2024-03-20T10:00:00.000Z'
      };

      final message = MessageModel.fromJson(json);
      expect(message.senderId, 'user_1');
      expect(message.senderName, isNull);
    });
  });
}
