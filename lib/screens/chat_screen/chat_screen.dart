import 'dart:io';
import 'package:chat_flutter/screens/chat_screen/components/chat_message.dart';
import 'package:chat_flutter/screens/chat_screen/components/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  FirebaseUser _currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.onAuthStateChanged.listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_currentUser != null
            ? "Olá, ${_currentUser.displayName}"
            : "ChatFlutter"),
        elevation: 0,
        actions: <Widget>[
          _currentUser != null
              ? IconButton(
                  icon: Icon(Icons.exit_to_app),
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                    googleSignIn.signOut();
                    _showSnackbar(texto: "Você saiu com sucesso!");
                  },
                )
              : Container()
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
              child: StreamBuilder<QuerySnapshot>(
            stream: Firestore.instance
                .collection("mensagens")
                .orderBy("time")
                .snapshots(),
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                case ConnectionState.waiting:
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                default:
                  List<DocumentSnapshot> documents =
                      snapshot.data.documents.reversed.toList();
                  return ListView.builder(
                      itemCount: documents.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        return ChatMessage(documents[index].data,
                            documents[index].data["uid"] == _currentUser?.uid);
                      });
              }
            },
          )),
          _isLoadingImage ? LinearProgressIndicator() : Container(),
          TextComposer(_sendMessage)
        ],
      ),
    );
  }

  //autenticar com o google
  Future<FirebaseUser> _getUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final GoogleSignInAccount googleSignInAccount =
          await googleSignIn.signIn();
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.getCredential(
          idToken: googleSignInAuthentication.idToken,
          accessToken: googleSignInAuthentication.accessToken);

      final AuthResult authResult =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final FirebaseUser user = authResult.user;

      return user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  _showSnackbar({String texto, Color cor}) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: cor,
    ));
  }

  _sendMessage({String texto, File imageFile}) async {
    final FirebaseUser user = await _getUser();

    if (user == null) {
      _showSnackbar(texto: "Não foi possivel fazer o login!", cor: Colors.red);
    }

    Map<String, dynamic> data = {
      "uid": user.uid,
      "senderName": user.displayName,
      "senderPhotoUrl": user.photoUrl,
      "time": Timestamp.now() //Timestamp é um objeto do firebase
    };

    if (imageFile != null) {
      StorageUploadTask task = FirebaseStorage.instance
          .ref()
          .child(_currentUser.uid)
          .child(DateTime.now().millisecondsSinceEpoch.toString())
          .putFile(imageFile);

      setState(() {
        _isLoadingImage = true;
      });

      StorageTaskSnapshot taskSnapshot = await task.onComplete;
      String url = await taskSnapshot.ref.getDownloadURL();
      data['imageUrl'] = url;

      setState(() {
        _isLoadingImage = false;
      });
    }

    if (texto != null) data['texto'] = texto;

    Firestore.instance.collection("mensagens").add(data);
  }
}
