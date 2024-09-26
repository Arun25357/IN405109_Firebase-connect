import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Authentication
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import FontAwesome
import 'package:todolist_app/screen/signin_screen.dart'; 
import 'package:todolist_app/screen/signup_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Initialize Firebase for Web
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyBEUl46zvLBJU13F6mvKzRnqrUalWnzygI",
        authDomain: "todolistapp-3f4bb.firebaseapp.com",
        projectId: "todolistapp-3f4bb",
        storageBucket: "todolistapp-3f4bb.appspot.com",
        messagingSenderId: "1041591250854",
        appId: "1:1041591250854:web:a4402cca2023d5be24a967",
        measurementId: "G-MWSNVJG89S"
      ),
    );
  } else {
    // Initialize Firebase for Android or iOS
    await Firebase.initializeApp();
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light; // Default theme

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Todo',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
      ),
      themeMode: _themeMode, // Switch between themes
      home: SigninScreen(), // Start with SigninScreen
      routes: {
        '/signin': (context) => SigninScreen(),
        '/signup': (context) => SignupScreen(), // Add SignupScreen to routes
        // Add other routes here if necessary
      },
    );
  }
}

class TodoScreen extends StatefulWidget {
  final Function() onThemeChanged;
  final ThemeMode currentThemeMode;

  TodoScreen({required this.onThemeChanged, required this.currentThemeMode});

  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _detailController = TextEditingController(); // Controller for task details
  final CollectionReference _todosCollection = FirebaseFirestore.instance.collection('todos');

  // Sign out function
  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/signin'); // Navigate to SigninScreen after sign-out
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ToDoList',
          style: TextStyle(
            fontSize: 24.0,  // Set font size
            fontWeight: FontWeight.bold,  // Set font weight to bold
            color: Color.fromARGB(255, 227, 138, 100),  // Set font color to white
            letterSpacing: 1.5,  // Add some spacing between letters for a cleaner look
          ),
        ),
        backgroundColor: Color.fromARGB(255, 118, 231, 116),  // Keep the background color as primary theme color (teal)
        actions: [
          // Add Sign Out Button
          IconButton(
            icon: FaIcon(FontAwesomeIcons.signOutAlt), // FontAwesome Sign Out icon
            onPressed: _signOut, // Call sign-out function
            color: Color.fromARGB(255, 227, 138, 100),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder(
                  stream: _todosCollection.snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                    // Sort tasks: uncompleted tasks first, then completed tasks
                    List<QueryDocumentSnapshot> sortedTasks = snapshot.data!.docs;
                    sortedTasks.sort((a, b) {
                      bool isCompletedA = a['isCompleted'] ?? false;
                      bool isCompletedB = b['isCompleted'] ?? false;
                      return isCompletedA == isCompletedB ? 0 : (isCompletedA ? 1 : -1);
                    });

                    return ListView(
                      children: sortedTasks.asMap().map((index, doc) {
                        bool isCompleted = doc['isCompleted'] ?? false;
                        // Define two colors for alternating based on theme
                        Color backgroundColor;
                        if (Theme.of(context).brightness == Brightness.light) {
                          backgroundColor = index.isEven ? Colors.teal[50]! : Colors.grey[200]!;
                        } else {
                          backgroundColor = index.isEven ? Colors.grey[800]! : Colors.grey[700]!;
                        }

                        return MapEntry(
                          index,
                          ListTile(
                            title: Text(
                              doc['task'],
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                                color: isCompleted ? Colors.grey : Theme.of(context).primaryColor,
                                decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                              ),
                            ),
                            subtitle: Text(
                              doc['detail'] ?? '', // Show task detail if available
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.grey[600],
                              ),
                            ),
                            leading: Checkbox(
                              value: isCompleted,
                              onChanged: (bool? value) {
                                _updateTodoWithPopup(doc.id, value!);
                              },
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: FaIcon(FontAwesomeIcons.pen), // FontAwesome edit icon
                                  color: Colors.blueAccent,
                                  onPressed: () => _showEditTodoDialog(context, doc.id, doc['task'], doc['detail']),
                                ),
                                IconButton(
                                  icon: FaIcon(FontAwesomeIcons.trash), // FontAwesome delete icon
                                  color: Colors.redAccent,
                                  onPressed: () => _deleteTodo(doc.id),
                                ),
                              ],
                            ),
                            tileColor: isCompleted ? Colors.grey[300] : backgroundColor, // Alternate colors
                          ),
                        );
                      }).values.toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddTodoDialog(context);
        },
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _addTodo() {
    if (_taskController.text.isNotEmpty) {
      _todosCollection.add({
        'task': _taskController.text,
        'detail': _detailController.text, // Store task detail
        'isCompleted': false,
      });
      _taskController.clear();
      _detailController.clear(); // Clear detail controller
    }
  }

  void _updateTodoWithPopup(String id, bool isCompleted) {
    _todosCollection.doc(id).update({'isCompleted': isCompleted});

    if (isCompleted) {
      // Show a "Finished" dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Task Finished"),
            content: Text("You have completed the task!"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  "OK",
                  style: TextStyle(color: Colors.teal),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _deleteTodo(String id) {
    _todosCollection.doc(id).delete();
  }

  void _showAddTodoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add New Task"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _taskController,
                decoration: InputDecoration(
                  hintText: 'Enter task description',
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                controller: _detailController, // Controller for detail
                decoration: InputDecoration(
                  hintText: 'Enter task details',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel button dismisses dialog
              },
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.redAccent), // Red color for Cancel button
              ),
            ),
            TextButton(
              onPressed: () {
                if (_taskController.text.isNotEmpty) {
                  _addTodo();
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                "Add",
                style: TextStyle(color: Colors.teal), // Teal color for Add button
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditTodoDialog(BuildContext context, String id, String currentTask, String currentDetail) {
    final TextEditingController _editTaskController = TextEditingController(text: currentTask);
    final TextEditingController _editDetailController = TextEditingController(text: currentDetail);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Task"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _editTaskController,
                decoration: InputDecoration(
                  hintText: 'Edit task description',
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                controller: _editDetailController, // Controller for editing detail
                decoration: InputDecoration(
                  hintText: 'Edit task details',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel button dismisses dialog
              },
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.redAccent), // Red color for Cancel button
              ),
            ),
            TextButton(
              onPressed: () {
                if (_editTaskController.text.isNotEmpty) {
                  _todosCollection.doc(id).update({
                    'task': _editTaskController.text,
                    'detail': _editDetailController.text, // Update task details
                    'isCompleted': false, // Mark as incomplete after edit
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                "Save",
                style: TextStyle(color: Colors.teal), // Teal color for Save button
              ),
            ),
          ],
        );
      },
    );
  }
}