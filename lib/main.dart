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
  @HiveField(4)
  DateTime updatedAtTime;

  Task({
    required this.title,
    required this.description,
    this.status = 'To Do',
    required this.createdAtTime,
    required this.updatedAtTime,
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
      updatedAtTime: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeString(obj.status);
    writer.writeString(obj.createdAtTime.toIso8601String());
    writer.writeString(obj.updatedAtTime.toIso8601String());
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
    _loadTasks();
  }

  void _loadTasks() {
    _tasks = _taskBox.values.toList();
    notifyListeners();
  }

  void addTask(String title, String description) {
    final now = DateTime.now();
    final task = Task(
      title: title,
      description: description,
      createdAtTime: now,
      updatedAtTime: now,
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
    task.updatedAtTime = DateTime.now();
    task.save();
    notifyListeners();
  }

  void deleteTask(int index) {
    _tasks[index].delete();
    _tasks.removeAt(index);
    notifyListeners();
  }
}

void _showTaskDialog(BuildContext context, TaskProvider taskProvider, Task? task) {
  final titleController = TextEditingController(text: task?.title);
  final descController = TextEditingController(text: task?.description);
  String status = task?.status ?? 'To Do';

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(task == null ? 'Add Task' : 'Edit Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: InputDecoration(labelText: 'Title')),
                TextField(controller: descController, decoration: InputDecoration(labelText: 'Description')),
                
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(labelText: 'Status'),
                  items: ['To Do', 'In Progress', 'Complete']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        status = value;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
              TextButton(
                child: Text(task == null ? 'Add' : 'Update'),
                onPressed: () {
                  if (task == null) {
                    taskProvider.addTask(titleController.text, descController.text);
                  } else {
                    taskProvider.updateTask(
                      taskProvider.tasks.indexOf(task),
                      titleController.text,
                      descController.text,
                      status,
                    );
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    },
  );
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
      appBar: AppBar(title: Text('Task Management')),
      body: Row(
        children: [
          Expanded(child: _buildTaskColumn(context, 'To Do', taskProvider, Colors.red[100]!)),
          Expanded(child: _buildTaskColumn(context, 'In Progress', taskProvider, Colors.yellow[100]!)),
          Expanded(child: _buildTaskColumn(context, 'Completed', taskProvider, Colors.green[100]!)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _showTaskDialog(context, taskProvider, null),
      ),
    );
  }
Widget _buildTaskColumn(BuildContext context, String status, TaskProvider taskProvider, Color color) {
  List<Task> tasks = taskProvider.tasks.where((task) => task.status == status).toList();

  return Container(
    color: color,
    padding: EdgeInsets.all(8),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center( // Ensures header is centered
            child: Text(
              status,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text(task.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: task.status,
                        onChanged: (value) {
                          if (value != null) {
                            taskProvider.updateTask(
                              taskProvider.tasks.indexOf(task),
                              task.title,
                              task.description,
                              value,
                            );
                          }
                        },
                        items: ['To Do', 'In Progress', 'Completed'].map((status) {
                          return DropdownMenuItem(value: status, child: Text(status));
                        }).toList(),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          _showTaskDialog(context, taskProvider, task);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          taskProvider.deleteTask(taskProvider.tasks.indexOf(task));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
}
