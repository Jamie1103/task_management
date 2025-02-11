import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding

  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());

  await Hive.openBox<Task>('tasksBox');

  runApp(MyApp());
}

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  String title;
  @HiveField(1)
  String description;
  @HiveField(2)
  String status;
  @HiveField(3)
  DateTime createdAtTime;

  Task({
    required this.title,
    required this.description,
    this.status = 'To Do',
    required this.createdAtTime,
  });
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    return Task(
      title: reader.readString(),
      description: reader.readString(),
      status: reader.readString(),
      createdAtTime: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeString(obj.status);
    writer.writeString(obj.createdAtTime.toIso8601String());
  }
}

class TaskProvider with ChangeNotifier {
  late Box<Task> _taskBox;
  List<Task> _tasks = [];

  List<Task> get tasks => _tasks;

  TaskProvider() {
    _initHive();
  }

  Future<void> _initHive() async {
    _taskBox = Hive.box<Task>('tasksBox');
    _cleanOldTasks();
    _loadTasks();
  }

  void _cleanOldTasks() {
    // Remove tasks from previous day
    for (var task in _taskBox.values.toList()) {
      if (task.createdAtTime.day != DateTime.now().day) {
        task.delete();
      }
    }
  }

  void _loadTasks() {
    _tasks = _taskBox.values.toList();
    notifyListeners();
  }

  void addTask(String title, String description) {
    final task = Task(
      title: title,
      description: description,
      createdAtTime: DateTime.now(),
    );
    _taskBox.add(task);
    _tasks.add(task);
    notifyListeners();
  }

  void updateTask(int index, String title, String description, String status) {
    final task = _tasks[index];
    task.title = title;
    task.description = description;
    task.status = status;
    task.save();
    notifyListeners();
  }

  void deleteTask(int index) {
    _tasks[index].delete();
    _tasks.removeAt(index);
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TaskProvider(),
      child: MaterialApp(
        home: TaskScreen(),
      ),
    );
  }
}

class TaskScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Task Manager')),
      body: ListView.builder(
        itemCount: taskProvider.tasks.length,
        itemBuilder: (context, index) {
          final task = taskProvider.tasks[index];
          return ListTile(
            title: Text(task.title),
            subtitle: Text(task.description),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: task.status,
                  onChanged: (value) {
                    if (value != null) {
                      taskProvider.updateTask(index, task.title, task.description, value);
                    }
                  },
                  items: ['To Do', 'In Progress', 'Complete'].map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    TextEditingController titleController = TextEditingController(text: task.title);
                    TextEditingController descController = TextEditingController(text: task.description);

                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Edit Task'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: titleController, decoration: InputDecoration(labelText: 'Title')),
                              TextField(controller: descController, decoration: InputDecoration(labelText: 'Description')),
                            ],
                          ),
                          actions: [
                            TextButton(
                              child: Text('Cancel'),
                              onPressed: () => Navigator.pop(context),
                            ),
                            TextButton(
                              child: Text('Update'),
                              onPressed: () {
                                taskProvider.updateTask(index, titleController.text, descController.text, task.status);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => taskProvider.deleteTask(index),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              TextEditingController titleController = TextEditingController();
              TextEditingController descController = TextEditingController();

              return AlertDialog(
                title: Text('Add Task'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleController, decoration: InputDecoration(labelText: 'Title')),
                    TextField(controller: descController, decoration: InputDecoration(labelText: 'Description')),
                  ],
                ),
                actions: [
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    child: Text('Add'),
                    onPressed: () {
                      taskProvider.addTask(titleController.text, descController.text);
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
