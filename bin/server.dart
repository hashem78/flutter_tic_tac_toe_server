import 'dart:async';
import 'dart:convert';

import 'package:socket_io/socket_io.dart';

var io = Server();

Map<String, List<int>> roomBoards = {};
Set<String> rooms = {};

class GameState {
  final int winner;
  final List<int> winningIndicies;

  const GameState(this.winner, this.winningIndicies);

  Map<String, dynamic> toMap() {
    return {
      'winner': winner,
      'winningIndicies': winningIndicies,
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map) {
    return GameState(
      map['winner'],
      List<int>.from(map['winningIndicies']),
    );
  }

  String toJson() => json.encode(toMap());

  factory GameState.fromJson(String source) =>
      GameState.fromMap(json.decode(source));
}

extension GameStateX on List<int> {
  GameState gameState() {
    for (int i = 0; i < 9; i += 3) {
      if (this[i] == this[i + 1] &&
          this[i] == this[i + 2] &&
          this[i + 1] == this[i + 2]) {
        if (this[i].abs() == 1 &&
            this[i + 1].abs() == 1 &&
            this[i + 2].abs() == 1) {
          return GameState(this[i], [i, i + 1, i + 2]);
        }
      }
    }
    //check coloumns
    for (int i = 0; i < 3; i += 1) {
      if (this[i] == this[i + 3] &&
          this[i] == this[i + 6] &&
          this[i + 3] == this[i + 6]) {
        if (this[i].abs() == 1 &&
            this[i + 3].abs() == 1 &&
            this[i + 6].abs() == 1) {
          return GameState(this[i], [i, i + 3, i + 6]);
        }
      }
    }
    //check main diagonal
    for (int i = 0; i <= 0; i += 1) {
      if (this[i] == this[i + 4] &&
          this[i] == this[i + 8] &&
          this[i + 4] == this[i + 8]) {
        if (this[i].abs() == 1 &&
            this[i + 4].abs() == 1 &&
            this[i + 8].abs() == 1) {
          return GameState(this[i], [i, i + 4, i + 8]);
        }
      }
    }
    //check anti diagonal
    for (int i = 2; i <= 2; i += 1) {
      if (this[i] == this[i + 2] &&
          this[i] == this[i + 4] &&
          this[i + 2] == this[i + 4]) {
        if (this[i].abs() == 1 &&
            this[i + 2].abs() == 1 &&
            this[i + 4].abs() == 1) {
          return GameState(this[i], [i, i + 2, i + 4]);
        }
      }
    }
    return const GameState(0, []);
  }
}

void main(List<String> arguments) {
  io.on(
    'connection',
    (c) async {
      final client = c as Socket;
      final roomNameController = StreamController<String>.broadcast();
      int? player;

      client.on(
        'room-create',
        (name) {
          print('${client.id} connected to room $name');
          if (!roomBoards.containsKey(name)) {
            print('room is not already connected');
            roomBoards[name] = List<int>.filled(9, 0);
            player = 1;
          }
        },
      );

      client.on(
        'request-player-type',
        (_) => client.emit(
          player.toString(),
        ),
      );

      client.on(
        'room-join',
        (room) {
          print('joined $room');
          player ??= -1;
          roomNameController.add(room);
          client.emit('board-state', roomBoards[room]);
          client.join(room);
        },
      );
      final roomName = await roomNameController.stream.first;
      print('roomName after awaiting: $roomName');
      client.on(
        'update-board-state',
        (position) {
          roomBoards[roomName]![position] = player!;
          print("update $roomName's board, it's now ${roomBoards[roomName]} ");

          final gameState = roomBoards[roomName]!.gameState();
          print('GameState: $gameState');

          io.to(roomName).emit('board-state', roomBoards[roomName]);
          if (gameState.winner.abs() == 1) {
            io.to(roomName).emit('win', gameState);
          }
          print("emmited to all connected clients");
        },
      );
      client.on(
        'reset',
        (_) {
          if (player == 1) {
            roomBoards[roomName]!.fillRange(0, 9, 0);
            io.to(roomName).emit('board-state', roomBoards[roomName]);
          }
        },
      );
      client.on(
        'disconnect',
        (data) {
          print('disconnected');
          roomBoards.remove(roomName);
          roomNameController.close();
        },
      );
    },
  );
  io.listen(19281);
}
