"""Dutch results, full per-lap table, source hashes and portable deliverables."""
import csv,json,statistics,hashlib,zipfile
from pathlib import Path
from collections import defaultdict
from experiments import ROOT

def read(name):
    with (ROOT/'results'/name).open(newline='',encoding='utf-8') as f:return list(csv.DictReader(f))

def main():
    tests=json.loads((ROOT/'results/tests.json').read_text(encoding='utf-8'))
    assert all(t['passed'] for t in tests)
    validation=next(t for t in tests if t['test']=='120_detailed_races_completed_zero_corrections_legal_following_distance')
    assert validation['source_sha256']==hashlib.sha256((ROOT/'source/elimination_v2.py').read_bytes()).hexdigest()
    rows=read('before_after.csv');frames=read('frame_sensitivity.csv');rounds=read('lap_speed_summary.csv');pairs=read('lap_pairs.csv')
    internal=read('internal_step_exploration.csv');no_override=read('no_override_probe.csv')
    def avg(label,key,predicate=lambda seed:True):
        return statistics.mean(float(r[key]) for r in rows if r['variant']==label and predicate(int(r['seed'])))
    seeds=sorted({int(r['seed']) for r in rows});n=len(seeds)
    fresh_start=max(seeds)-11
    lookup={(r['variant'],int(r['lap'])):r for r in rounds}
    table='\n'.join(f"{lap:>2}   {lookup['v2',lap]['type']:<17} {float(lookup['baseline',lap]['field_mean_kmh']):>8.2f} {float(lookup['v2',lap]['field_mean_kmh']):>8.2f} {float(lookup['v2',lap]['ai_mean_kmh']):>8.2f} {float(lookup['v2',lap]['leader_reference_kmh']):>8.2f}" for lap in range(1,31))
    cycle={label:[r for r in pairs if r['variant']==label and r['ordinary_cycle']=='True'] for label in ('baseline','v2')}
    cmeans={label:{key:statistics.mean(float(r[key]) for r in rr) for key in ('recovery_kmh','elimination_kmh','difference_kmh')} for label,rr in cycle.items()}
    good={label:sum(float(r['difference_kmh'])>0 for r in rr) for label,rr in cycle.items()}
    rounding_text=f'''GEMIDDELDE SNELHEID PER RONDE — {n} WEDSTRIJDEN, SEEDS {min(seeds)}-{max(seeds)}

Alle snelheden in km/u. Elke regel is het gemiddelde over dezelfde {n} races.
Oud = de eerder geleverde Python-fix. Nieuw = de uiteindelijke v2.
Veld = tijdgewogen gemiddelde van de fysieke snelheden van alle actieve renners
tijdens de betreffende ronde van de kop. AI = dezelfde meting zonder renner 0.
Kop = 250 m / tijd tussen opeenvolgende eerste doorkomsten, omgerekend naar km/u.
De kopmeting gebruikt de gemeenschappelijke referentieafstand; fysieke snelheden
omvatten de extra weg van buitenste rijlijnen. Het zijn verschillende maten.

Ronde  Type               Veld oud Veld nieuw AI nieuw Kop nieuw
{table}

GEWONE CYCLI (rondes 5-28, dus zonder staande start/aanval en finale)
                           Tussenronde  Afvallingsronde  Verschil
Oud                        {cmeans['baseline']['recovery_kmh']:.2f}         {cmeans['baseline']['elimination_kmh']:.2f}             {cmeans['baseline']['difference_kmh']:+.2f}
Nieuw                      {cmeans['v2']['recovery_kmh']:.2f}         {cmeans['v2']['elimination_kmh']:.2f}             {cmeans['v2']['difference_kmh']:+.2f}
Nieuwe afvallingsronde sneller in {good['v2']} van {len(cycle['v2'])} gepaarde cycli
({100*good['v2']/len(cycle['v2']):.1f}%). Oud: {good['baseline']} van {len(cycle['baseline'])}.

Een even ronde is een afvallingsronde; de oneven ronde ervoor is de tussenronde.
Ronde 1 bevat de staande start. De opgelegde 650 W-aanval loopt van 35 tot 60 s,
daarna vraagt renner 0 vast 250 W. Daardoor zijn vooral rondes 2-4 atypisch.
Rondes 29-30 zijn de finale met twee overblijvers. Alle rondes blijven in de
tabel en CSV's staan; alleen bovenstaande vergelijking sluit die fasen uit.
Fysieke uitputting en verkeerssituaties kunnen individuele cycli omkeren.

results/lap_speeds.csv: elke ronde per wedstrijd, met begin/einde/duur.
results/lap_speed_summary.csv: bovenstaande gemiddelden in machineleesbare vorm.
results/lap_pairs.csv: vergelijking van elk opeenvolgend paar oneven/even rondes.
results/rider_lap_speeds.csv: 250 m-splittijden en referentiesnelheid per renner.
De rondegrenzen worden binnen de integratiestap geïnterpoleerd. De meting
middelt dus niet alleen over een paar toevallig opgevraagde momentopnamen.
'''
    (ROOT/'RONDESNELHEDEN.txt').write_text(rounding_text,encoding='utf-8')
    fs=defaultdict(list)
    for r in frames:fs[(r['variant'],r['frame_dt'])].append(float(r['span_m']))
    # Only seven v2 seeds were independently rerun at every frame size. Compare
    # exactly that subset; do not average seven races against 36 races.
    matched={17,23,24,31,41,42,52,53,64,65,76}
    frame_table=[]
    for dt in ('0.1','0.2','0.4','0.13'):
        line=[]
        for label in ('baseline','v2'):
            rr=[r for r in frames if r['variant']==label and r['frame_dt']==dt and int(r['seed']) in matched]
            line.append(f"{statistics.mean(float(r['span_m']) for r in rr):.2f} m" if len(rr)==len(matched) else 'niet gemeten')
        frame_table.append(f"{dt:>4} s         {line[0]:>14}   {line[1]:>14}")
    internal_table='\n'.join(f"{h:>5} s        {statistics.mean(float(r['span_m']) for r in internal if r['integration_dt']==h):.2f} m" for h in ('0.1','0.05','0.025'))
    diag=json.loads((ROOT/'results/diagnostics.json').read_text(encoding='utf-8'))
    total_caps={label:sum(diag[f'{label}_{s}']['counts']['speed_caps'] for s in seeds) for label in ('baseline','v2')}
    cap_time={label:sum(diag[f'{label}_{s}']['counts']['speed_caps']*(.2 if label=='baseline' else .05) for s in seeds) for label in ('baseline','v2')}
    rider_time={label:sum(diag[f'{label}_{s}']['counts']['rider_ticks']*(.2 if label=='baseline' else .05) for s in seeds) for label in ('baseline','v2')}
    worse=[r['seed'] for r in rows if r['variant']=='v2' and float(r['span_m'])>next(float(b['span_m']) for b in rows if b['variant']=='baseline' and b['seed']==r['seed'])]
    report=f'''VERVOLGONDERZOEK AFVALLING — 9 november 2026

UITKOMST
De resterende kunstmatige spreiding is verder verkleind. Voor de oorspronkelijke
zeven seeds (17-23) gaat de gemiddelde spreiding van {avg('baseline','span_m',lambda s:s<24):.2f} naar
{avg('v2','span_m',lambda s:s<24):.2f} m. Dat is de vergelijking met de reeds gecorrigeerde versie,
niet met het oorspronkelijke experiment van 138,87 m.

Over alle {n} wedstrijden (seeds {min(seeds)}-{max(seeds)}, 16 renners, difficulty 80):
                                   Eerdere fix        Nieuwe v2
Gem. spreiding                      {avg('baseline','span_m'):.2f} m            {avg('v2','span_m'):.2f} m
Gem. AI-spreiding zonder renner 0    {avg('baseline','mean_ai_span_m'):.2f} m            {avg('v2','mean_ai_span_m'):.2f} m
Gem. snelheid eliminatiefase        {avg('baseline','elimination_kmh'):.2f} km/u          {avg('v2','elimination_kmh'):.2f} km/u
Gem. slipstreamsterkte              {avg('baseline','draft'):.3f}                {avg('v2','draft'):.3f}
Gem. W-prime-fractie na lijnen      {avg('baseline','mean_wprime_after_eliminations'):.3f}                {avg('v2','mean_wprime_after_eliminations'):.3f}
Botsingscorrecties per wedstrijd    0                    0

Het totale tempo is lager doordat de extra snelheidsvraag is verwijderd.
De slipstreamsterkte daalt ook: een kleinere longitudinale spreiding betekent
niet automatisch betere wieluitlijning; renners kunnen meer naast elkaar
rijden. Dat blijft een beperking van deze versie, zichtbaar in bovenstaande
cijfers. De hogere resterende W-prime komt uit minder onnodige inspanning,
niet uit aangepaste energieparameters.

De laatste twaalf seeds ({fresh_start}-{max(seeds)}) zijn pas na het kiezen van de natuurlijke
positioneringsregeling toegevoegd. Hun gemiddelde spreiding is {avg('baseline','span_m',lambda s:s>=fresh_start):.2f} m vóór en
{avg('v2','span_m',lambda s:s>=fresh_start):.2f} m na de wijziging.
De twaalf eerdere nieuwe seeds (29-40): {avg('baseline','span_m',lambda s:29<=s<=40):.2f} naar
{avg('v2','span_m',lambda s:29<=s<=40):.2f} m.
Seeds met een grotere gemiddelde spreiding na de wijziging: {', '.join(worse) if worse else f'geen binnen deze {n} races'}.
De grootste momentane spreiding over alle races is {max(float(r['max_span_m']) for r in rows if r['variant']=='baseline'):.2f} m oud
en {max(float(r['max_span_m']) for r in rows if r['variant']=='v2'):.2f} m nieuw. Gemiddelden zijn dus geen
garantie dat elk groot gat onder alle omstandigheden verdwijnt.

BEWEZEN OORZAKEN EN CORRECTIES
1. Vermogen werd geboekt voordat duidelijk was welke beweging de rijlijn toeliet.
   Een ingesloten volger kon daardoor W-prime verbruiken aan 400 W en vervolgens
   toch tot het tempo van zijn voorganger worden begrensd. Nu wordt eerst de
   haalbare vermogensvraag uit de bewegingsruimte berekend, daarna pas CP,
   W-prime, Pmax en vermoeidheid afgerekend. Geen terugbetaling achteraf en
   geen extra energie. Het bestaande snelheidsvangnet blijft bestaan voor
   situaties waarin alleen uitrollen niet voldoende kan vertragen.
2. De oude rijlijncontrole beschouwde afzonderlijke veeggebieden als een botsing,
   ook wanneer twee renners parallel dezelfde kant op bewogen of uiteen gingen.
   Nu wordt hun onderlinge laterale afstand gedurende de gezamenlijke beweging
   getoetst. Samenlopende trajecten en kruisingen blijven geblokkeerd als de
   longitudinale ruimte ontbreekt. Het model houdt dezelfde 0,60 m rijlijnafstand.
   Een tweede fout blokkeerde het verlaten van een veilig wiel: de planner
   eiste ook daarvoor de 3,6 m-buffer voor NIEUWE invoegbewegingen, terwijl de
   volger rond 3,2 m bleef rijden. Nu wordt voor een vertrekkend traject apart
   gecontroleerd of de bestaande 2 m-volgafstand tijdens de afscheiding veilig
   blijft. Nieuwe invoegbewegingen houden hun ruimere buffer. In de gerichte
   probleemseeds 25 en 36 verdwijnt daardoor de onnodige AI-kloof van circa 93 m.
3. Wielvolgen vergeleek fysieke snelheden alsof alle rijlijnen even lang waren.
   Nu worden wieltempo en verkeersvoorspelling naar dezelfde referentieafstand
   omgerekend. De vermogensvraag bevat bovendien de versnelling die nodig is
   om het doeltempo te bereiken, in plaats van alleen het evenwichtsvermogen.
4. De hoge afvallingsurgentie bleef soms doorlopen tot de laatste renner de
   lijn passeerde. Nu reset de tactische cyclus op de 500 m-grens van de kop.
5. De minimumsnelheidsregeling is OP VERZOEK VOLLEDIG VERWIJDERD. Er is geen
   universele vraag naar 41,4-44,3 km/u meer. Cruisen gebruikt de bestaande
   vermogenskeuze; volgen/sluiten gebruikt het wieltempo, de afstand en de
   benodigde versnelling; positioneren gebruikt rang, afstand tot de volgende
   jury en het eigen CP/W-prime/Pmax. De positioneringsvoorbereiding begint nu
   50 m vóór de bel van de afvallingsronde; de urgentie is volledig bij nog
   200 m tot de afvalling. Zo is er tijd om een veilige route te reserveren en
   werkelijk op snelheid te komen. Er wordt geen doelsnelheid opgelegd.

   Alleen de snelheidsankerregel weglaten hield in 48 proefraces het veld
   compact, maar maakte de afvallingsrondes gemiddeld niet sneller: de versnelling kwam te laat en
   liep door in de volgende tussenronde. Extra defensieve inspanning op basis
   van marge tot de laatste renner bleek evenmin de juiste oplossing. Beide
   proeven staan in no_floor_* en position_defense_*; deze opties zijn niet
   als verborgen snelheidsvloer teruggebracht. De uiteindelijke wijziging is
   eerder positioneren met de bestaande ranggebonden vermogenscurve.

De opgelegde proef blijft 650 W voor renner 0 van 35-60 s, daarna 250 W.
Dat is een vermogensvraag: ook deze renner valt onder de fysieke grenzen en
de verkeersregeling. Een geblokkeerde aanval hoeft daardoor niet werkelijk
650 W te blijven verbruiken terwijl zijn snelheid kunstmatig wordt afgeknipt.
De Pmax/CP/W-prime/fatigue-parameters, startopstelling en eliminatieregels blijven
gelijk. De vorige verwijdering van het foutieve buitenbaanplafond blijft behouden.

RONDESNELHEDEN
Gemiddelden van de gewone gepaarde cycli, rondes 5-28, over alle {n} races:
                         Tussenronde       Afvallingsronde
Eerdere fix              {cmeans['baseline']['recovery_kmh']:.2f} km/u         {cmeans['baseline']['elimination_kmh']:.2f} km/u
Nieuwe v2                {cmeans['v2']['recovery_kmh']:.2f} km/u         {cmeans['v2']['elimination_kmh']:.2f} km/u
Het nieuwe verschil is {cmeans['v2']['difference_kmh']:+.2f} km/u. In {good['v2']}/{len(cycle['v2'])} individuele
gepaarde cycli is de afvallingsronde sneller. De volledige tabel van ALLE
dertig rondes, inclusief start/aanval en finale, staat in RONDESNELHEDEN.txt.
De meting gebruikt tijdgewogen fysieke veldsnelheden en geïnterpoleerde
rondegrenzen, met daarnaast afzonderlijke 250 m-splittijden van kop en renners.

TIJDSTAP: TWEE VERSCHILLENDE VRAGEN
A. Aanroep-/frame-interval van de gebruiker of game-loop.
De oude simulator liet dit rechtstreeks de fysica en beslismomenten bepalen.
De nieuwe simulator heeft een vaste integratiestap van 0,05 s, een beslisklok
van 0,20 s en een meetklok van 0,50 s. Een accumulator verdeelt willekeurige
frame-intervallen over dezelfde gehele interne ticks. Geen tijd wordt overgeslagen.
Voor seeds 17,23,24,31,41,42,52,53,64,65,76 is bij frame-intervallen 0,10 / 0,20 / 0,40 /
0,13 s elke interne toestand (positie, snelheid, W-prime en rijlijn) identiek,
bevestigd met hashes over het volledige verloop. Ook de uitslagen zijn exact gelijk.

Gem. spreiding over precies deze elf frame-testseeds:
Frame-interval           Eerdere fix          Nieuwe v2
{chr(10).join(frame_table)}

B. De echte fysieke integratiestap.
Externe frame-onafhankelijkheid bewijst GEEN numerieke convergentie. Daarom is
ook integration_dt gevarieerd, bij dezelfde beslisklok van 0,20 s en meetklok
van 0,50 s. Zeven seeds: 17,23,24,25,26,27,28.
Integratiestap       Gem. spreiding v2
{internal_table}
De individuele uitslagen en trajecten zijn bij deze echte verfijning niet
identiek. Discrete wielkeuze, rijlijnreservering en eliminaties kunnen kleine
afwijkingen nog versterken. De gemeten resterende gevoeligheid staat dus
expliciet in de resultaten; niet elke vorm van tijdstapgevoeligheid is verdwenen.
De standaardinstelling is 0,05 s. integration_dt moet de beslis- en meetklok delen.

VEILIGHEID EN TESTS
Alle {2*n} volledig geobserveerde hoofdwedstrijden zijn voltooid met nul noodcorrecties.
Iedere stap controleert niet-achteruitrijden, minimaal 2 m afstand tot de
veiligheidsvoorganger in dezelfde rijlijn en geldige W-prime-grenzen.
Het passief gelogde oude model levert exact dezelfde resultaten als de
ongewijzigde eerder geleverde fix. tests.json bevat daarnaast gerichte proeven
voor energieboekhouding, parallelle/uiteengaande/kruisende rijlijnbewegingen,
de snelheidsmaat op 9 rijlijncombinaties, versnellingsfeedback, het terugzetten
van urgentie en het behoud van de aansluitvraag voor geloste renners.

Ruwe aantallen snelheidsbegrenzingen zijn niet rechtstreeks vergelijkbaar omdat
de nieuwe fysica viermaal zo vaak loopt. Begrensde renner-tijd als fractie van
alle actieve renner-tijd: oud {100*cap_time['baseline']/rider_time['baseline']:.2f}%, nieuw
{100*cap_time['v2']/rider_time['v2']:.2f}%. De nieuwe vermogensregeling anticipeert op
verkeer; noodzakelijke snelheidsingrepen zijn niet uitgeschakeld.

WAT OVERBLIJFT
Een gecontroleerde renner die na een aanval vast 250 W vraagt kan op eigen
kracht alsnog lossen. AI-renners kunnen fysiek hun W-prime opgebruiken.
Een oorzaakproef zonder de externe 650/250 W-override geeft voor seeds 17-40
gemiddeld {statistics.mean(float(r['span_m']) for r in no_override):.2f} m spreiding en een grootste
momentane spreiding van {max(float(r['max_span_m']) for r in no_override):.2f} m. Dit is alleen
een diagnoseproef; de geleverde v2 houdt de override actief.

span_m blijft absolute wedstrijdvoortgang van alle actieve renners, niet de
kleinste bezette boog op de piste. Veiligheid in dit onderzoeksmodel gebruikt
eveneens absolute voortgang; ontmoetingen met gedubbelde renners modulo 250 m
vallen buiten het model. De rijlijnwissels zijn discreet en bochten/slipstream
zijn benaderingen. Nul correcties betekent daarom geen volledige fysieke
validatie van een echte piste of van de Godot-game.

BESTANDEN EN UITVOEREN
source/elimination_v2.py: leesbare, zelfstandig uitvoerbare nieuwe simulator.
baseline/: de ongewijzigde eerder geleverde fix met haar afhankelijkheden.
source/changes.patch: het volledige verschil tussen die versies.
source/validate.py: hoofdvergelijking, rijlijnafstanden, tijdstap- en rondetests.
source/clock_probes.py: echte integratieverfijning bij vaste beslisklok.
results/before_after.csv: alle {2*n} hoofdwedstrijden.
results/frame_sensitivity.csv: de frame-intervalvergelijkingen.
results/internal_step_exploration.csv: de 21 echte verfijningswedstrijden.
results/lap_*.csv en rider_lap_speeds.csv: alle ronde- en rennersplits.
results/diagnostics.json: grote-gatgebeurtenissen, maxima en tellingen per race.
results/trace_*.csv.gz: vier voorbeeldraces, per renner gelogd op 0,20 s-cadans.
results/pre_recovery/, pre_departure/, pre_natural_pace/: tussenresultaten.
Overige *_exploration.csv-bestanden documenteren de onderzochte alternatieven.
provenance.json: bron- en resultaathashes. GitHub is niet gewijzigd.

Vanuit deze map, Python 3.12, uitsluitend standaardbibliotheek:
python source/elimination_v2.py --seed 17 --dt 0.4 --lap-csv rondes_seed17.csv
python source/validate.py
python source/clock_probes.py
python source/no_override_probe.py
python source/package_results.py

dt is nu het externe aanroepinterval. integration_dt is afzonderlijk instelbaar
via --integration-dt; alleen die parameter verfijnt de echte fysica.
'''
    (ROOT/'RAPPORT.txt').write_text(report,encoding='utf-8')
    hashes={}
    for p in sorted(ROOT.rglob('*')):
        if p.is_file() and '__pycache__' not in p.parts and p.name!='provenance.json':
            hashes[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    (ROOT/'provenance.json').write_text(json.dumps(dict(date='2026-11-09',baseline='previously delivered predictive_fixed.py',github_changes=False,sha256=hashes),indent=2),encoding='utf-8')
    for full in (False,True):
        path=ROOT.parent/(ROOT.name+('_met_logs.zip' if full else '_code_en_resultaten.zip'))
        with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for p in sorted(ROOT.rglob('*')):
                if p.is_file() and '__pycache__' not in p.parts and (full or p.suffix!='.gz'):
                    z.write(p,ROOT.name+'/'+p.relative_to(ROOT).as_posix())
        with zipfile.ZipFile(path) as z:assert z.testzip() is None
        print(path.name,path.stat().st_size,flush=True)
    print('Ordinary lap cycles',cmeans,good,flush=True)

if __name__=='__main__':main()
