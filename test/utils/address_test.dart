import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/utils/address.dart';

// The extractor is made for Dutch addresses (anchored on the Dutch postcode), so the
// inputs here deliberately stay Dutch.
void main() {
  test('street on the line above the postcode', () {
    expect(
      extractAddress('Sportcentrum Voorbeeld\nDorpsstraat 12\n1234 AB Ons Dorp\nTel. 010-0000000'),
      'Dorpsstraat 12, 1234 AB Ons Dorp',
    );
  });

  test('everything on one line, with a label', () {
    expect(
      extractAddress('Bezoekadres: Dorpsstraat 12a, 1234AB Ons Dorp'),
      'Dorpsstraat 12a, 1234AB Ons Dorp',
    );
  });

  test('the line above the postcode is not a street (no house number)', () {
    expect(extractAddress('Kom langs!\n1234 AB Ons Dorp'), '1234 AB Ons Dorp');
  });

  test('no postcode: rather nothing than a guess', () {
    expect(extractAddress('Bel ons op 010-0000000\ninfo@example.org'), isNull);
    expect(extractAddress('Opgericht in 1987 AD'), isNull);
  });
}
