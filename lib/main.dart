import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() => runApp(const ManjezApp());

class Task {
  String id,title,description,category,priority;
  DateTime? due;
  bool done;
  Task({required this.id,required this.title,this.description='',this.category='شخصي',this.priority='متوسطة',this.due,this.done=false});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'description':description,'category':category,'priority':priority,'due':due?.toIso8601String(),'done':done};
  factory Task.fromJson(Map<String,dynamic> j)=>Task(id:j['id'],title:j['title'],description:j['description']??'',category:j['category']??'شخصي',priority:j['priority']??'متوسطة',due:j['due']==null?null:DateTime.parse(j['due']),done:j['done']??false);
}

class ManjezApp extends StatefulWidget { const ManjezApp({super.key}); @override State<ManjezApp> createState()=>_AppState(); }
class _AppState extends State<ManjezApp>{
  ThemeMode mode=ThemeMode.system;
  @override Widget build(BuildContext c)=>MaterialApp(title:'منجز',debugShowCheckedModeBanner:false,themeMode:mode,theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo,brightness:Brightness.light),darkTheme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo,brightness:Brightness.dark),home: Home(onTheme:(m)=>setState(()=>mode=m)));
}

class Home extends StatefulWidget { final ValueChanged<ThemeMode> onTheme; const Home({super.key,required this.onTheme}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home>{
  List<Task> tasks=[]; String filter='الكل'; String search='';
  final cats=['شخصي','دراسة','عمل','تسوق','أخرى'];
  @override void initState(){super.initState();load();}
  Future load() async {final p=await SharedPreferences.getInstance(); final s=p.getString('tasks'); if(s!=null) tasks=(jsonDecode(s) as List).map((e)=>Task.fromJson(e)).toList(); if(mounted)setState((){});}
  Future save() async {final p=await SharedPreferences.getInstance(); await p.setString('tasks',jsonEncode(tasks.map((e)=>e.toJson()).toList()));}
  List<Task> get visible=>tasks.where((t)=>(filter=='الكل'||t.category==filter)&&(search.isEmpty||t.title.contains(search))).toList();
  Future edit([Task? old]) async {final title=TextEditingController(text:old?.title); final desc=TextEditingController(text:old?.description); String cat=old?.category??'شخصي', pri=old?.priority??'متوسطة'; DateTime? due=old?.due;
    await showDialog(context:context,builder:(d)=>StatefulBuilder(builder:(d,set)=>AlertDialog(title:Text(old==null?'إضافة مهمة':'تعديل المهمة'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:title,decoration:const InputDecoration(labelText:'اسم المهمة',prefixIcon:Icon(Icons.task_alt))),
      TextField(controller:desc,decoration:const InputDecoration(labelText:'الوصف')),
      DropdownButtonFormField(value:cat,items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>set(()=>cat=x!),decoration:const InputDecoration(labelText:'التصنيف')),
      DropdownButtonFormField(value:pri,items:['منخفضة','متوسطة','عالية'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>set(()=>pri=x!),decoration:const InputDecoration(labelText:'الأولوية')),
      ListTile(leading:const Icon(Icons.calendar_month),title:Text(due==null?'موعد التنفيذ':DateFormat('yyyy/MM/dd HH:mm').format(due!)),onTap:()async{final date=await showDatePicker(context:d,firstDate:DateTime.now(),lastDate:DateTime(2100),initialDate:due??DateTime.now());if(date!=null){final time=await showTimePicker(context:d,initialTime:TimeOfDay.fromDateTime(due??DateTime.now()));if(time!=null)set(()=>due=DateTime(date.year,date.month,date.day,time.hour,time.minute));}}),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('إلغاء')),FilledButton(onPressed:(){if(title.text.trim().isEmpty)return;final t=old??Task(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim());t.title=title.text.trim();t.description=desc.text.trim();t.category=cat;t.priority=pri;t.due=due;if(old==null)tasks.add(t);save();setState((){});Navigator.pop(d);},child:Text(old==null?'إضافة':'حفظ'))]));}
  @override Widget build(BuildContext c){final done=tasks.where((x)=>x.done).length; return Scaffold(appBar:AppBar(title:const Text('منجز',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(icon:const Icon(Icons.search),onPressed:()=>showSearch(context:context,delegate:TaskSearch(tasks,onPick:(x){edit(x);}))),IconButton(icon:const Icon(Icons.settings),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Settings(onTheme:widget.onTheme))))]),body:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('مهامك اليوم',style:Theme.of(c).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:6),Text('$done من ${tasks.length} مكتملة',style:Theme.of(c).textTheme.bodyLarge),
      const SizedBox(height:16),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:['الكل',...cats].map((x)=>Padding(padding:const EdgeInsetsDirectional.only(end:8),child:ChoiceChip(label:Text(x),selected:filter==x,onSelected:(_)=>setState(()=>filter=x))).toList())),
      const SizedBox(height:12),Expanded(child:visible.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.task_alt,size:64,color:Theme.of(c).colorScheme.primary),const SizedBox(height:12),const Text('لا توجد مهام بعد'),const SizedBox(height:8),const Text('اضغط + لإضافة أول مهمة')])):ListView.builder(itemCount:visible.length,itemBuilder:(c,i){final t=visible[i];return Card(child:ListTile(leading:Checkbox(value:t.done,onChanged:(v){setState(()=>t.done=v??false);save();}),title:Text(t.title,style:TextStyle(decoration:t.done?TextDecoration.lineThrough:null,fontWeight:FontWeight.w600)),subtitle:Text('${t.category} • ${t.priority}${t.due==null?'':' • '+DateFormat('MM/dd HH:mm').format(t.due!)}'),onTap:()=>edit(t),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:(){setState(()=>tasks.remove(t));save();}));})),
    ])),floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('مهمة جديدة')));
  }
}
class TaskSearch extends SearchDelegate<Task?>{final List<Task> tasks;final void Function(Task) onPick;TaskSearch(this.tasks,{required this.onPick});@override List<Widget>? buildActions(c)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear))];@override Widget buildLeading(c)=>IconButton(onPressed:()=>close(c,null),icon:const Icon(Icons.arrow_back));@override Widget buildResults(c)=>_list();@override Widget buildSuggestions(c)=>_list();Widget _list()=>ListView(children:tasks.where((t)=>t.title.contains(query)).map((t)=>ListTile(title:Text(t.title),subtitle:Text(t.category),onTap:(){close(context,t);onPick(t);})).toList());}
class Settings extends StatelessWidget{final ValueChanged<ThemeMode> onTheme;const Settings({super.key,required this.onTheme});@override Widget build(c)=>Scaffold(appBar:AppBar(title:const Text('الإعدادات')),body:ListView(padding:const EdgeInsets.all(12),children:[
Card(child:Column(children:[const ListTile(title:Text('المظهر',style:TextStyle(fontWeight:FontWeight.bold))),RadioListTile(value:ThemeMode.system,groupValue:ThemeMode.system,onChanged:(_)=>onTheme(ThemeMode.system),title:const Text('تلقائي حسب النظام')),RadioListTile(value:ThemeMode.light,groupValue:ThemeMode.system,onChanged:(_)=>onTheme(ThemeMode.light),title:const Text('فاتح')),RadioListTile(value:ThemeMode.dark,groupValue:ThemeMode.system,onChanged:(_)=>onTheme(ThemeMode.dark),title:const Text('داكن'))])),const ListTile(leading:Icon(Icons.notifications_outlined),title:Text('الإشعارات'),subtitle:Text('سيتم تفعيل التذكيرات في المرحلة التالية')),const ListTile(leading:Icon(Icons.info_outline),title:Text('عن منجز'),subtitle:Text('منجز — مدير مهام يومي'))]));}
