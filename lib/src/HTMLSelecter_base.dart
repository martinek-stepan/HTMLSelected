import 'package:html/dom.dart';
import 'HTMLSelecter_internal.dart';
import 'dart:collection';

List<Element> $(String query, var source) {
  List<Element> elements = getSourceElements(source);
  List<QueryItem> parts = parseQuery(query);

  List<Set<Element>> stages = List<Set<Element>>(parts.length + 1);
  for (int i = 0; i < (parts.length + 1); i++)
  {
    stages[i] = LinkedHashSet<Element>();
  }
  stages[0].addAll(elements);
  for (int stage = 0; stage < parts.length; stage++) {

    Set<Element> data = stages[stage];
    while (data.isNotEmpty) {
      QueryItem queryItem = parts[stage];
      Element element = data.first;
      data.remove(element);

      if (match(element, queryItem)) {
        if (queryItem.relationship == null)
        {
          stages[stage + 1].add(element);
        }

        switch(queryItem.relationship)
        {
          case Relationship.AllDescendants:
          case Relationship.DirectChilds:
            stages[stage + 1].addAll(element.children);
            break;

          case Relationship.SameLevel:
            if (element.parent != null)
            {
              stages[stage + 1].addAll(element.parent.children);
            }
            else
            {
              stages[stage+1].add(element);
            }
            break;
          case Relationship.Siblings:
            stages[stage + 1].add(element.nextElementSibling);
            stages[stage + 1].add(element.previousElementSibling);
            break;
        }
      }

      if (queryItem.includeDescendants) {
        data.addAll(element.children);
      }
    }
  }

  return stages[stages.length - 1].toList();
}