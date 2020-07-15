import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

List<Element> getSourceElements(var source) {
  List<Element> elements = List<Element>();
  if (source is String) {
    elements.add(parse(source).documentElement);
  } else if (source is Document) {
    elements.add(source.documentElement);
  } else if (source is Element) {
    elements.add(source);
  } else if (source is List<Document>) {
    elements.addAll(source.map((e) => e.documentElement));
  }

  return elements;
}

enum Relationship
{
  AllDescendants,
  DirectChilds,
  SameLevel,
  Siblings
}

enum Identifier
{
  Element,
  Class,
  Id,
  AllElements,
  Custom
}

class AndPart
{
  AndPart(this.identifier, this.value, [this.customIdentifier]);
  Identifier identifier;
  String customIdentifier;
  String value = "";
}

class QueryItem {
  QueryItem(
    this.orParts,
    [this.includeDescendants, this.relationship]
    );

  List<List<AndPart>> orParts;
  bool includeDescendants = true;
  Relationship relationship = Relationship.AllDescendants;

}

bool match(Element element, QueryItem queryItem) {
  for (var orPart in queryItem.orParts)
  {
    if( checkAndCondition(element, orPart))
    {
      return true;
    }
  }
  return false;
}

bool checkAndCondition(Element element, List<AndPart> andParts) {

  for (var andPart in andParts)
  {
    switch(andPart.identifier)
    {
      case Identifier.AllElements:
        return true;
      case Identifier.Id:
        if (element.id != andPart.value)
          return false;
        break;
      case Identifier.Element:
        if (element.localName != andPart.value)
          return false;
        break;
      case Identifier.Class:
        if (!element.classes.contains(andPart.value))
          return false;
        break;
      case Identifier.Custom:
        {
          var attr = element.attributes[andPart.customIdentifier];
          if (attr != andPart.value)
          {
            return false;
          }
        }

    }
  }

  return true;
}

const String ESCAPE_CONST = "\\";


void closeSequence(List<AndPart> andParts, StringBuffer buffer, Identifier identifier)
{
  if (buffer.isNotEmpty)
  {
    if (identifier != Identifier.Custom)
    {
      andParts.add(AndPart(identifier,buffer.toString()));
    }
    else
    {
      var parts = buffer.toString().split("=");
      if (parts.length == 2)
      {
        andParts.add(AndPart(identifier, parts[1], parts[0]));
      }
    }
  }
  buffer.clear();
}

List<List<AndPart>> parseOrParts(String part)
{
  var orParts = part.split(",");
  List<List<AndPart>> ors = [];
  int k = 0;
  for(var orPart in orParts)
  {
    List<AndPart> ands = [];
    ors.add(ands);

    if (orPart.isEmpty || orPart[0] == '*')
    {
      ands.add(AndPart(Identifier.AllElements, ""));
      continue;
    }

    List<AndPart> andParts = [];
    var buffer = StringBuffer();
    var identifier = Identifier.Element;
    bool escaped = false;
    for(int i=0;i<orPart.length; i++)
    {
      var char = orPart[i];
      if (!escaped  && char == ESCAPE_CONST)
      {
        escaped = true;
        continue;
      }

      switch(escaped ? '' : char)
      {
        case '#':
          closeSequence(ands, buffer, identifier);
          identifier = Identifier.Id;
          break;
        case '.':
          closeSequence(ands, buffer, identifier);
          identifier = Identifier.Class;
          break;
        case '[':
          closeSequence(ands, buffer, identifier);
          identifier = Identifier.Custom;
          break;
        case ']':
          closeSequence(ands, buffer, identifier);
          break;
        default:
          buffer.write(char);
          break;
      }
      escaped = false;
    }
    if (ors.isEmpty)
    {
      ors.add([]);
    }
    closeSequence(ors.last, buffer, identifier);

  }
  return ors;
}

List<QueryItem> parseQuery(String query) {

  List<QueryItem> queryItems = [];
  var withoutSpaces = query.replaceAllMapped(RegExp(r'\s*([>+~ ])\s*'), (match){ return '${match.group(1)}';});

  StringBuffer buffer = StringBuffer();
  for(int i=0;i<withoutSpaces.length; i++)
  {
    switch(withoutSpaces[i])
    {
      case '>':
        queryItems.add(QueryItem(parseOrParts(buffer.toString()), false, Relationship.DirectChilds));
        buffer.clear();
        break;
      case '+':
        queryItems.add(QueryItem(parseOrParts(buffer.toString()), false, Relationship.SameLevel));
        buffer.clear();
        break;
      case '~':
        queryItems.add(QueryItem(parseOrParts(buffer.toString()), false, Relationship.Siblings));
        buffer.clear();
        break;
      case ' ':
        queryItems.add(QueryItem(parseOrParts(buffer.toString()), true, Relationship.AllDescendants));
        buffer.clear();
        break;
      default:
        buffer.write(withoutSpaces[i]);
        break;
    }
  }
  queryItems.add(QueryItem(parseOrParts(buffer.toString()),false));

  for (int i=1; i<queryItems.length; i++)
  {
    queryItems[i].includeDescendants = queryItems[i-1].includeDescendants;
  }

  queryItems[0].includeDescendants = true;

  return queryItems;
}