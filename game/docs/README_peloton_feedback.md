# Peloton, wedstrijdpositie en ontsnappingen

## Wedstrijdpositie en punten zijn apart

De afgelegde afstand blijft een cumulatieve kilometerteller voor fysieke beweging, rondetijden en opnames. De wedstrijdpositie is die afstand **min het toegekende rondeverschil maal 250 m**. Na rondewinst wordt de wedstrijdpositie dus 250 m teruggezet, zonder een zichtbare sprong op de cirkel. De +20 punten blijven behouden. Na rondeverlies geldt de omgekeerde correctie.

Deze gecorrigeerde positie bepaalt in puntenkoers ook de AI-context en de rondeklok voor volgende sprints en finish. Een eerder gewonnen ronde kan daardoor niet alsnog een sprint of de finish een ronde te vroeg openen.

**Rondom jou** toont de zes dichtste renners op deze wedstrijdpositie, met hun volledige wedstrijdplaats en meterafstand voor/achter jou. De speler blijft erbij. Dit is geen puntenrangschikking. De afstand ten opzichte van de kop of staart van het grootste peloton staat apart links en onderaan; binnen de grenzen staat er ‘In het peloton’.

De puntenrangschikking staat rechts onder de minimap, met alle deelnemers. De uitslag blijft volgens punten en de laatste sprint geordend. Scratch bewaart zijn eigen officiële rangschikking op rondeverschil; de lokale fysieke positie en afstand hoeven daarmee niet samen te vallen.

## Pelotongrenzen en rondeberichten

Het grootste fysieke peloton wordt voor jury en presentatie op dezelfde manier herkend. De kop krijgt een **oranje** dwarsstrook; de staart een **turquoise** strook. Beide zijn virtueel en beïnvloeden de fysica niet. Labels staan op de buitenkant van de baan. Op de minimap wordt het peloton geaccentueerd met dezelfde grenzen en K/S-markeringen. Als geen compacte groep van minstens drie renners bestaat, wordt geen fictief peloton getoond.

Bij eigen rondewinst verschijnt tien seconden een expliciete melding met **RONDE GEWONNEN · +20 PUNTEN · TERUG IN HET PELOTON**, plus een kort geluid. Ook rondeverlies en rondewinsten/-verliezen van AI-renners worden vermeld. De eigen melding heeft voorrang op AI-berichten.

## Energie boven de renner

Zowel scratch als puntenkoers tonen boven de actieve renners een naamkaart met huidig werkelijk geleverd vermogen en batterij. De AI-batterij gebruikt de **echte resterende W′ gedeeld door de individuele maximale W′**, met groen/oranje/rood voor de reserve. In puntenkoers staat ook het aantal punten op de kaart. De losse naamlabels worden tijdens de race vervangen door deze kaarten; kaarten worden niet meegefotografeerd in de finishfoto.

Voor de menselijke speler zijn het werkelijke ingangsvermogen en de punten beschikbaar, maar is in deze spelmodi nog geen persoonlijk CP/W′-profiel ingesteld. Daarom staat de menselijke energiereserve op **W′ —**, zonder een verzonnen percentage of aanpassing van het trainervermogen.

## Beurtwisselingen in ontsnappingen

De speler telt nu mee bij de herkenning van een kleine ontsnapping. Daardoor is een duo speler/AI een echte groep en kunnen twee of drie ontsnapte renners ronddraaien. Een menselijke kopbeurt wordt alleen herkend wanneer de speler werkelijk vooraan rijdt en vermogen levert; de code stuurt of vertraagt de speler niet automatisch.

Een AI die aan de beurt is, kiest een vrije passeerlijn en vraagt voldoende vermogen om naar voren te komen. Daarna volgt een normale kopbeurt en beurtwisseling. De vermogensduurcurve, CP, W′, vermoeidheid en botsingsvermijding blijven begrenzen wat haalbaar is. Overnemen verbruikt dus energie; een uitgeputte AI krijgt geen gratis versnelling.

## Controle

`tests/test_peloton_feedback.gd` controleert onder meer:

- +20 punten en een wedstrijdpositie terug in het peloton, met behoud van de fysieke kilometerteller;
- geen vervroegde sprint/finish door een al gewonnen ronde;
- aparte fysieke meterafstanden en puntenrangschikking;
- zichtbare grensobjecten en minimap-/pelotoninformatie;
- batterijpercentage, werkelijk vermogen, punten en onbekende menselijke reserve;
- een duo speler/AI en een echte ontsnapping waarin twee AI-renners fysiek overnemen, met W′-verbruik;
- de expliciete rondewinstmelding.

De HUD-tests zijn aangepast aan de gevraagde fysieke rangschikking en de afzonderlijke pelotonafstand. De volledige puntenkoers-, scratch-, wielvolg-, start-, energie-, achtervolgings-, trainer- en menutests worden mee uitgevoerd. De schermen voor puntenkoers, rondewinst en scratch zijn met de renderer nagekeken. Geen fysieke trainerhardwaretest uitgevoerd.
