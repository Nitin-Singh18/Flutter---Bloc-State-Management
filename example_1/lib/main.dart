import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocProvider(create: (_) => PersonBloc(), child: const HomePage()),
    );
  }
}

@immutable
abstract class LoadAction {
  const LoadAction();
}

//this enum contains two URLs
enum PersonUrl {
  persons1,
  persons2,
}

@immutable
class LoadPersonAction implements LoadAction {
  final PersonUrl url;
  const LoadPersonAction({required this.url}) : super();
}

extension UrlString on PersonUrl {
  String get urlString {
    switch (this) {
      case PersonUrl.persons1:
        return "http://10.0.2.2:5500/api/person1.json";

      case PersonUrl.persons2:
        return "http://10.0.2.2:5500/api/person2.json";
    }
  }
}

//Person mdoel class0
@immutable
class Person {
  final String name;
  final int age;

  const Person({required this.name, required this.age});

  Person.fromJson(Map<String, dynamic> map)
      : name = map['name'] as String,
        age = map['age'] as int;
}

//Download and parse json using HttpClient
Future<Iterable<Person>> getPersons(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((resp) => resp.transform(utf8.decoder).join())
    .then((str) => jsonDecode(str) as List<dynamic>)
    .then((list) => list.map((e) => Person.fromJson(e)));

//Result of the blloc
@immutable
class FetchResult {
  final Iterable<Person> persons;
  //boolean indicating whether the data was retrieved from cache or not
  final bool isRetrievedFrommCache;

  const FetchResult(
      {required this.persons, required this.isRetrievedFrommCache});

  @override
  String toString() =>
      'FetchResult (isRetrievedFromCache = $isRetrievedFrommCache, person = $persons)';
}

//Bloc class which takes LoadAction as input and FetchResult as output.
class PersonBloc extends Bloc<LoadAction, FetchResult?> {
  final Map<PersonUrl, Iterable<Person>> _cache = {};
  PersonBloc() : super(null)
  //Handle LoadPersonAction in the constructor
  {
    //event -> input of bloc
    //emit -> output of bloc
    on<LoadPersonAction>((event, emit) async {
      final url = event.url;

      if (_cache.containsKey(url)) {
        //getting value that we have in the cache
        final cachedPersons = _cache[url];
        final result =
            FetchResult(persons: cachedPersons!, isRetrievedFrommCache: true);
        emit(result);
      } else {
        //getting data from url
        final persons = await getPersons(url.urlString);
        _cache[url] = persons;
        final result =
            FetchResult(persons: persons, isRetrievedFrommCache: false);
        emit(result);
      }
    });
  }
}

extension Subscript<T> on Iterable<T> {
  T? operator [](int index) => length > index ? elementAt(index) : null;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home Page"),
      ),
      body: Column(
        children: [
          Row(
            children: [
              TextButton(
                  onPressed: () {
                    context.read<PersonBloc>().add(
                          const LoadPersonAction(url: PersonUrl.persons1),
                        );
                  },
                  child: const Text("Load Json 1")),
              TextButton(
                  onPressed: () {
                    context.read<PersonBloc>().add(
                          const LoadPersonAction(url: PersonUrl.persons2),
                        );
                  },
                  child: const Text("Load Json 2"))
            ],
          ),
          BlocBuilder<PersonBloc, FetchResult?>(
              buildWhen: (previousResult, currentResult) {
            return previousResult?.persons != currentResult!.persons;
          }, builder: ((context, fetchResult) {
            final persons = fetchResult?.persons;
            if (persons == null) {
              return Container(
                height: 40,
                width: 40,
                color: Colors.black,
              );
            }
            return Expanded(
              child: ListView.builder(
                  itemCount: persons.length,
                  itemBuilder: ((context, index) {
                    final person = persons[index];
                    return ListTile(
                      title: Text(
                        person!.name,
                        style:
                            const TextStyle(color: Colors.black, fontSize: 30),
                      ),
                      subtitle: Text(person.age.toString()),
                    );
                  })),
            );
          }))
        ],
      ),
    );
  }
}
