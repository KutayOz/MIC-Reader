/// Supported organisms for EUCAST breakpoint interpretation
enum Organism {
  cAlbicans('C. albicans', 'Candida albicans'),
  cAuris('C. auris', 'Candida auris'),
  cDubliniensis('C. dubliniensis', 'Candida dubliniensis'),
  cGlabrata('C. glabrata', 'Candida glabrata'),
  cKrusei('C. krusei', 'Candida krusei'),
  cParapsilosis('C. parapsilosis', 'Candida parapsilosis'),
  cTropicalis('C. tropicalis', 'Candida tropicalis'),
  cGuilliermondii('C. guilliermondii', 'Candida guilliermondii'),
  cryptoNeoformans('C. neoformans', 'Cryptococcus neoformans');

  final String shortName;
  final String fullName;

  const Organism(this.shortName, this.fullName);
}
