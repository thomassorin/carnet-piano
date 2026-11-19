#!/usr/bin/env python3
"""Génère PianoJournal/Resources/catalog.json (catalogue embarqué, consultable hors ligne).
Usage : python3 tools/build_catalog.py"""
import json, re, unicodedata, os

ITEMS = []
def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")

def add(composer, title, kind="piece", period=None, level=None, genre=None, pieces=None):
    ITEMS.append({"id": slug(composer.split()[-1] + "-" + title), "title": title, "composer": composer,
                  "kind": kind, "period": period, "level": level, "genre": genre, "pieces": pieces})

def col(composer, title, period, level, genre, pieces): add(composer, title, "collection", period, level, genre, pieces)
def met(composer, title, level, pieces=None): add(composer, title, "method", None, level, "Méthode", pieces)
def num(n, prefix="N° ", start=1): return [f"{prefix}{i}" for i in range(start, start + n)]
def keyed(prefix, keys, suffix=None):
    out = []
    for i, k in enumerate(keys, 1):
        s = f"{prefix} n° {i} en {k}"
        if suffix: s += suffix(i)
        out.append(s)
    return out

BACH, MOZ, BEE, CHO, SCHU, DEB = "Johann Sebastian Bach", "Wolfgang Amadeus Mozart", "Ludwig van Beethoven", "Frédéric Chopin", "Robert Schumann", "Claude Debussy"
B, C, R, M, K, P = "baroque", "classique", "romantique", "moderne", "contemporain", "populaire"

# ───────── Bach
inv = ["do majeur","do mineur","ré majeur","ré mineur","mi♭ majeur","mi majeur","mi mineur","fa majeur","fa mineur","sol majeur","sol mineur","la majeur","la mineur","si♭ majeur","si mineur"]
col(BACH, "Inventions à deux voix, BWV 772-786", B, 3, "Invention", [f"Invention n° {i} en {k}, BWV {771+i}" for i, k in enumerate(inv, 1)])
col(BACH, "Sinfonies (Inventions à trois voix), BWV 787-801", B, 4, "Invention", [f"Sinfonia n° {i} en {k}, BWV {786+i}" for i, k in enumerate(inv, 1)])
wtc = ["do majeur","do mineur","do♯ majeur","do♯ mineur","ré majeur","ré mineur","mi♭ majeur","mi♭ mineur","mi majeur","mi mineur","fa majeur","fa mineur","fa♯ majeur","fa♯ mineur","sol majeur","sol mineur","la♭ majeur","sol♯ mineur","la majeur","la mineur","si♭ majeur","si♭ mineur","si majeur","si mineur"]
col(BACH, "Le Clavier bien tempéré, Livre I, BWV 846-869", B, 4, "Prélude et fugue", [f"Prélude et fugue n° {i} en {k}, BWV {845+i}" for i, k in enumerate(wtc, 1)])
col(BACH, "Le Clavier bien tempéré, Livre II, BWV 870-893", B, 5, "Prélude et fugue", [f"Prélude et fugue n° {i} en {k}, BWV {869+i}" for i, k in enumerate(wtc, 1)])
col(BACH, "Petit livre d'Anna Magdalena Bach", B, 2, "Recueil", [
 "Menuet en fa majeur, BWV Anh. 113","Menuet en sol majeur, BWV Anh. 114 (Petzold)","Menuet en sol mineur, BWV Anh. 115 (Petzold)","Menuet en sol majeur, BWV Anh. 116",
 "Polonaise en fa majeur, BWV Anh. 117","Menuet en si♭ majeur, BWV Anh. 118","Polonaise en sol mineur, BWV Anh. 119","Menuet en la mineur, BWV Anh. 120",
 "Menuet en do mineur, BWV Anh. 121","Marche en ré majeur, BWV Anh. 122","Polonaise en sol mineur, BWV Anh. 123","Marche en sol majeur, BWV Anh. 124",
 "Polonaise en sol mineur, BWV Anh. 125","Musette en ré majeur, BWV Anh. 126","Marche en mi♭ majeur, BWV Anh. 127","Polonaise en ré mineur, BWV Anh. 128",
 "Solo per il cembalo en mi♭ majeur, BWV Anh. 129","Polonaise en sol majeur, BWV Anh. 130","Menuet en ré mineur, BWV Anh. 132",
 "Prélude en do majeur, BWV 846/1","Aria « Bist du bei mir », BWV 508","Aria des Variations Goldberg, BWV 988/1","Choral « Wer nur den lieben Gott lässt walten », BWV 691"])
col(BACH, "Six petits préludes, BWV 933-938", B, 2, "Prélude", [f"Petit prélude n° {i} en {k}, BWV {932+i}" for i, k in enumerate(["do majeur","do mineur","ré mineur","ré majeur","mi majeur","mi mineur"], 1)])
col(BACH, "Suites françaises, BWV 812-817", B, 4, "Suite", [f"Suite française n° {i} en {k}, BWV {811+i}" for i, k in enumerate(["ré mineur","do mineur","si mineur","mi♭ majeur","sol majeur","mi majeur"], 1)])
col(BACH, "Suites anglaises, BWV 806-811", B, 5, "Suite", [f"Suite anglaise n° {i} en {k}, BWV {805+i}" for i, k in enumerate(["la majeur","la mineur","sol mineur","fa majeur","mi mineur","ré mineur"], 1)])
col(BACH, "Partitas, BWV 825-830", B, 5, "Suite", [f"Partita n° {i} en {k}, BWV {824+i}" for i, k in enumerate(["si♭ majeur","do mineur","la mineur","ré majeur","sol majeur","mi mineur"], 1)])
col(BACH, "Variations Goldberg, BWV 988", B, 5, "Variations", ["Aria"] + [f"Variation {i}" for i in range(1, 31)] + ["Aria da capo"])
add(BACH, "Concerto italien, BWV 971", "piece", B, 5, "Concerto")
add(BACH, "Prélude en do majeur, BWV 846", "piece", B, 2, "Prélude")
add(BACH, "Jésus, que ma joie demeure, BWV 147 (transcription)", "piece", B, 3, "Choral")
add("Georg Friedrich Haendel", "Sarabande en ré mineur, HWV 437", "piece", B, 2, "Sarabande")
add("Georg Friedrich Haendel", "Passacaille en sol mineur, HWV 432", "piece", B, 4, "Passacaille")
add("Johann Pachelbel", "Canon en ré majeur (transcription)", "piece", B, 3, "Canon")
add("Domenico Scarlatti", "Sonate en ré mineur, K. 1", "piece", B, 4, "Sonate")
add("Domenico Scarlatti", "Sonate en si mineur, K. 27", "piece", B, 4, "Sonate")
add("Domenico Scarlatti", "Sonate en mi majeur, K. 380", "piece", B, 4, "Sonate")
add("Domenico Scarlatti", "Sonate en ré mineur, K. 141", "piece", B, 5, "Sonate")
add("Jean-Philippe Rameau", "Le Tambourin", "piece", B, 3, "Pièce de clavecin")
add("Jean-Philippe Rameau", "Les Sauvages", "piece", B, 4, "Pièce de clavecin")
add("François Couperin", "Les Barricades mystérieuses", "piece", B, 4, "Pièce de clavecin")
add("Louis-Claude Daquin", "Le Coucou", "piece", B, 4, "Pièce de clavecin")

# ───────── Classique
col(MOZ, "Sonates pour piano (intégrale)", C, 4, "Sonate", [f"Sonate n° {i} en {k}, K. {kv}{n}" for i, (k, kv, n) in enumerate([
 ("do majeur","279",""),("fa majeur","280",""),("si♭ majeur","281",""),("mi♭ majeur","282",""),("sol majeur","283",""),("ré majeur","284",""),
 ("do majeur","309",""),("la mineur","310",""),("ré majeur","311",""),("do majeur","330",""),("la majeur","331"," « Alla turca »"),("fa majeur","332",""),
 ("si♭ majeur","333",""),("do mineur","457",""),("fa majeur","533/494",""),("do majeur","545"," « Sonate facile »"),("si♭ majeur","570",""),("ré majeur","576","")], 1)])
add(MOZ, "Marche turque (Rondo alla turca), K. 331", "piece", C, 3, "Rondo")
add(MOZ, "Fantaisie en ré mineur, K. 397", "piece", C, 3, "Fantaisie")
add(MOZ, "Douze variations sur « Ah ! vous dirai-je, maman », K. 265", "piece", C, 3, "Variations")
add(MOZ, "Rondo en ré majeur, K. 485", "piece", C, 3, "Rondo")
add(MOZ, "Adagio en si mineur, K. 540", "piece", C, 4, "Adagio")
col(BEE, "Sonates pour piano (intégrale)", C, 5, "Sonate", [f"Sonate n° {i} en {k}, op. {op}{n}" for i, (k, op, n) in enumerate([
 ("fa mineur","2 n° 1",""),("la majeur","2 n° 2",""),("do majeur","2 n° 3",""),("mi♭ majeur","7",""),("do mineur","10 n° 1",""),("fa majeur","10 n° 2",""),("ré majeur","10 n° 3",""),
 ("do mineur","13"," « Pathétique »"),("mi majeur","14 n° 1",""),("sol majeur","14 n° 2",""),("si♭ majeur","22",""),("la♭ majeur","26",""),("mi♭ majeur","27 n° 1",""),
 ("do♯ mineur","27 n° 2"," « Clair de lune »"),("ré majeur","28"," « Pastorale »"),("sol majeur","31 n° 1",""),("ré mineur","31 n° 2"," « La Tempête »"),("mi♭ majeur","31 n° 3",""),
 ("sol mineur","49 n° 1",""),("sol majeur","49 n° 2",""),("do majeur","53"," « Waldstein »"),("fa majeur","54",""),("fa mineur","57"," « Appassionata »"),("fa♯ majeur","78",""),
 ("sol majeur","79",""),("mi♭ majeur","81a"," « Les Adieux »"),("mi mineur","90",""),("la majeur","101",""),("si♭ majeur","106"," « Hammerklavier »"),("mi majeur","109",""),
 ("la♭ majeur","110",""),("do mineur","111","")], 1)])
add(BEE, "Lettre à Élise (Bagatelle en la mineur, WoO 59)", "piece", C, 2, "Bagatelle")
add(BEE, "Sonate « Clair de lune », op. 27 n° 2 — 1er mouvement", "piece", C, 3, "Sonate")
add(BEE, "Sonatine en sol majeur, Anh. 5 n° 1", "piece", C, 1, "Sonatine")
add(BEE, "Sonatine en fa majeur, Anh. 5 n° 2", "piece", C, 2, "Sonatine")
add(BEE, "Écossaise en sol majeur, WoO 23", "piece", C, 1, "Danse")
add(BEE, "Rondo a capriccio « La Colère pour un sou perdu », op. 129", "piece", C, 5, "Rondo")
col(BEE, "Bagatelles, op. 33", C, 3, "Bagatelle", num(7, "Bagatelle n° "))
col(BEE, "Bagatelles, op. 119", C, 3, "Bagatelle", num(11, "Bagatelle n° "))
col(BEE, "Bagatelles, op. 126", C, 4, "Bagatelle", num(6, "Bagatelle n° "))
col("Muzio Clementi", "Six sonatines, op. 36", C, 2, "Sonatine", keyed("Sonatine", ["do majeur","sol majeur","do majeur","fa majeur","sol majeur","ré majeur"]))
col("Friedrich Kuhlau", "Trois sonatines, op. 20", C, 2, "Sonatine", keyed("Sonatine", ["do majeur","sol majeur","fa majeur"]))
col("Friedrich Kuhlau", "Six sonatines, op. 55", C, 2, "Sonatine", keyed("Sonatine", ["do majeur","sol majeur","do majeur","fa majeur","ré majeur","do majeur"]))
add("Joseph Haydn", "Sonate en do majeur, Hob. XVI:35", "piece", C, 3, "Sonate")
add("Joseph Haydn", "Sonate en ré majeur, Hob. XVI:37", "piece", C, 4, "Sonate")
add("Joseph Haydn", "Sonate en mi♭ majeur, Hob. XVI:52", "piece", C, 5, "Sonate")

# ───────── Études & technique
for op, n, lvl, t in [("599", 100, 1, "Premier maître du piano (100 exercices), op. 599"), ("139", 100, 2, "100 exercices progressifs, op. 139"), ("849", 30, 3, "30 études de mécanisme, op. 849"),
                      ("299", 40, 4, "L'École de la vélocité, op. 299"), ("740", 50, 5, "L'Art de délier les doigts, op. 740"), ("261", 125, 2, "125 exercices de traits, op. 261")]:
    col("Carl Czerny", t, C, lvl, "Étude", num(n))
col("Charles-Louis Hanon", "Le Pianiste virtuose en 60 exercices", R, 2, "Exercice", num(60, "Exercice n° "))
col("Ferdinand Beyer", "École préparatoire de piano, op. 101", R, 1, "Méthode", num(106))
col("Jean-Baptiste Duvernoy", "École primaire (25 études faciles), op. 176", R, 1, "Étude", num(25, "Étude n° "))
col("Jean-Baptiste Duvernoy", "École du mécanisme (15 études), op. 120", R, 3, "Étude", num(15, "Étude n° "))
col("Henry Lemoine", "Études enfantines, op. 37", R, 2, "Étude", num(50, "Étude n° "))
col("Stephen Heller", "25 études mélodiques, op. 45", R, 3, "Étude", num(25, "Étude n° "))
col("Stephen Heller", "30 études progressives, op. 46", R, 3, "Étude", num(30, "Étude n° "))
col("Stephen Heller", "25 études pour le rythme et l'expression, op. 47", R, 2, "Étude", num(25, "Étude n° "))
col("Henri Bertini", "25 études faciles et progressives, op. 100", R, 2, "Étude", num(25, "Étude n° "))
col("Johann Baptist Cramer", "60 études choisies (Cramer-Bülow)", C, 4, "Étude", num(60, "Étude n° "))
col("Moritz Moszkowski", "15 études de virtuosité, op. 72", R, 5, "Étude", num(15, "Étude n° "))
col("Friedrich Burgmüller", "25 études faciles et progressives, op. 100", R, 2, "Étude", [f"{i}. {t}" for i, t in enumerate([
 "La Candeur","L'Arabesque","La Pastorale","La Petite Réunion","Innocence","Progrès","Le Courant limpide","La Gracieuse","La Chasse","Tendre Fleur","La Bergeronnette","L'Adieu","Consolation",
 "La Styrienne","Ballade","Douce Plainte","La Babillarde","Inquiétude","Ave Maria","La Tarentelle","L'Harmonie des anges","Barcarolle","Le Retour","L'Hirondelle","La Chevaleresque"], 1)])
col("Friedrich Burgmüller", "18 études de genre, op. 109", R, 3, "Étude", [f"{i}. {t}" for i, t in enumerate([
 "Confidence","Les Perles","Le Retour du pâtre","Les Bohémiens","La Source","L'Enjouée","Berceuse","Agitato","La Cloche des matines","La Vélocité","La Sérénade","Le Réveil dans les bois",
 "L'Orage","Refrain du gondolier","Les Sylphes","La Séparation","Marche","La Fileuse"], 1)])

# ───────── Chopin
col(CHO, "Nocturnes (intégrale)", R, 4, "Nocturne", ["Nocturne en si♭ mineur, op. 9 n° 1","Nocturne en mi♭ majeur, op. 9 n° 2","Nocturne en si majeur, op. 9 n° 3","Nocturne en fa majeur, op. 15 n° 1",
 "Nocturne en fa♯ majeur, op. 15 n° 2","Nocturne en sol mineur, op. 15 n° 3","Nocturne en do♯ mineur, op. 27 n° 1","Nocturne en ré♭ majeur, op. 27 n° 2","Nocturne en si majeur, op. 32 n° 1",
 "Nocturne en la♭ majeur, op. 32 n° 2","Nocturne en sol mineur, op. 37 n° 1","Nocturne en sol majeur, op. 37 n° 2","Nocturne en do mineur, op. 48 n° 1","Nocturne en fa♯ mineur, op. 48 n° 2",
 "Nocturne en fa mineur, op. 55 n° 1","Nocturne en mi♭ majeur, op. 55 n° 2","Nocturne en si majeur, op. 62 n° 1","Nocturne en mi majeur, op. 62 n° 2","Nocturne en mi mineur, op. 72 n° 1 (posth.)",
 "Nocturne en do♯ mineur, op. posth. (Lento con gran espressione)","Nocturne en do mineur, op. posth."])
pk = ["do majeur","la mineur","sol majeur","mi mineur","ré majeur","si mineur","la majeur","fa♯ mineur","mi majeur","do♯ mineur","si majeur","sol♯ mineur","fa♯ majeur","mi♭ mineur","ré♭ majeur","si♭ mineur","la♭ majeur","fa mineur","mi♭ majeur","do mineur","si♭ majeur","sol mineur","fa majeur","ré mineur"]
col(CHO, "24 Préludes, op. 28", R, 4, "Prélude", keyed("Prélude", pk, lambda i: " « La goutte d'eau »" if i == 15 else ""))
col(CHO, "Valses (intégrale)", R, 4, "Valse", ["Grande valse brillante en mi♭ majeur, op. 18","Valse en la♭ majeur, op. 34 n° 1","Valse en la mineur, op. 34 n° 2","Valse en fa majeur, op. 34 n° 3",
 "Valse en la♭ majeur, op. 42","Valse en ré♭ majeur, op. 64 n° 1 « Valse minute »","Valse en do♯ mineur, op. 64 n° 2","Valse en la♭ majeur, op. 64 n° 3","Valse en la♭ majeur, op. 69 n° 1 « L'Adieu »",
 "Valse en si mineur, op. 69 n° 2","Valse en sol♭ majeur, op. 70 n° 1","Valse en fa mineur, op. 70 n° 2","Valse en ré♭ majeur, op. 70 n° 3","Valse en mi mineur, op. posth.","Valse en la mineur, op. posth."])
col(CHO, "12 Études, op. 10", R, 5, "Étude", keyed("Étude", ["do majeur","la mineur","mi majeur","do♯ mineur","sol♭ majeur","mi♭ mineur","do majeur","fa majeur","fa mineur","la♭ majeur","mi♭ majeur","do mineur"],
    lambda i: {3: " « Tristesse »", 5: " « Sur les touches noires »", 12: " « Révolutionnaire »"}.get(i, "")))
col(CHO, "12 Études, op. 25", R, 5, "Étude", keyed("Étude", ["la♭ majeur","fa mineur","fa majeur","la mineur","mi mineur","sol♯ mineur","do♯ mineur","ré♭ majeur","sol♭ majeur","si mineur","la mineur","do mineur"],
    lambda i: {1: " « Harpe éolienne »", 9: " « Papillon »", 11: " « Vent d'hiver »", 12: " « Océan »"}.get(i, "")))
col(CHO, "Ballades", R, 5, "Ballade", ["Ballade n° 1 en sol mineur, op. 23","Ballade n° 2 en fa majeur, op. 38","Ballade n° 3 en la♭ majeur, op. 47","Ballade n° 4 en fa mineur, op. 52"])
col(CHO, "Scherzos", R, 5, "Scherzo", ["Scherzo n° 1 en si mineur, op. 20","Scherzo n° 2 en si♭ mineur, op. 31","Scherzo n° 3 en do♯ mineur, op. 39","Scherzo n° 4 en mi majeur, op. 54"])
col(CHO, "Impromptus", R, 5, "Impromptu", ["Impromptu n° 1 en la♭ majeur, op. 29","Impromptu n° 2 en fa♯ majeur, op. 36","Impromptu n° 3 en sol♭ majeur, op. 51","Fantaisie-Impromptu en do♯ mineur, op. 66"])
col(CHO, "Polonaises", R, 5, "Polonaise", ["Polonaise en do♯ mineur, op. 26 n° 1","Polonaise en mi♭ mineur, op. 26 n° 2","Polonaise en la majeur, op. 40 n° 1 « Militaire »","Polonaise en do mineur, op. 40 n° 2",
 "Polonaise en fa♯ mineur, op. 44","Polonaise en la♭ majeur, op. 53 « Héroïque »","Polonaise-Fantaisie en la♭ majeur, op. 61"])
add(CHO, "Berceuse en ré♭ majeur, op. 57", "piece", R, 5, "Berceuse")
add(CHO, "Barcarolle en fa♯ majeur, op. 60", "piece", R, 5, "Barcarolle")
add(CHO, "Nocturne en mi♭ majeur, op. 9 n° 2", "piece", R, 3, "Nocturne")
add(CHO, "Prélude en mi mineur, op. 28 n° 4", "piece", R, 2, "Prélude")
add(CHO, "Valse en la mineur, op. posth.", "piece", R, 2, "Valse")
add(CHO, "Fantaisie-Impromptu en do♯ mineur, op. 66", "piece", R, 5, "Impromptu")

# ───────── Schumann, Schubert, Mendelssohn, Brahms, Liszt, Grieg, Tchaïkovski
col(SCHU, "Scènes d'enfants (Kinderszenen), op. 15", R, 3, "Pièce de caractère", [f"{i}. {t}" for i, t in enumerate([
 "Gens et pays étrangers","Curieuse histoire","Colin-maillard","L'enfant suppliant","Bonheur parfait","Un événement important","Rêverie (Träumerei)","Au coin du feu",
 "Cavalier sur le cheval de bois","Presque trop sérieux","Croquemitaine","L'enfant s'endort","Le poète parle"], 1)])
col(SCHU, "Album pour la jeunesse, op. 68", R, 2, "Pièce de caractère", [f"{i}. {t}" for i, t in enumerate([
 "Mélodie","Marche des soldats","Chanson fredonnée","Choral","Petite pièce","Pauvre orphelin","Chanson de chasse","Le cavalier sauvage","Chanson populaire","Le gai laboureur","Sicilienne",
 "Le Père Fouettard (Knecht Ruprecht)","Mai, cher mai","Petite étude","Chant du printemps","Premier chagrin","Petit promeneur du matin","Chant des moissonneurs","Petite romance","Chant paysan",
 "Sans titre (***)","Ronde","Le cavalier","Chant de la moisson","Souvenir du théâtre","Sans titre (***)","Petit chant en canon","Souvenir","L'étranger","Sans titre (***)","Chant de guerre",
 "Shéhérazade","Temps des vendanges, temps joyeux","Thème","Mignon","Chanson des marins italiens","Chanson des matelots","L'hiver I","L'hiver II","Petite fugue","Chanson nordique",
 "Choral figuré","Chant de la Saint-Sylvestre"], 1)])
col(SCHU, "Scènes de la forêt (Waldszenen), op. 82", R, 4, "Pièce de caractère", [f"{i}. {t}" for i, t in enumerate([
 "Entrée","Chasseur à l'affût","Fleurs solitaires","Lieu maudit","Paysage souriant","L'auberge","L'oiseau prophète","Chanson de chasse","Adieu"], 1)])
add(SCHU, "Arabesque en do majeur, op. 18", "piece", R, 4, "Pièce de caractère")
add(SCHU, "Rêverie (Träumerei), op. 15 n° 7", "piece", R, 3, "Pièce de caractère")
col("Franz Schubert", "Impromptus, op. 90 (D. 899)", R, 4, "Impromptu", keyed("Impromptu", ["do mineur","mi♭ majeur","sol♭ majeur","la♭ majeur"]))
col("Franz Schubert", "Impromptus, op. 142 (D. 935)", R, 5, "Impromptu", keyed("Impromptu", ["fa mineur","la♭ majeur","si♭ majeur","fa mineur"]))
col("Franz Schubert", "Moments musicaux, D. 780", R, 4, "Pièce de caractère", keyed("Moment musical", ["do majeur","la♭ majeur","fa mineur","do♯ mineur","fa mineur","la♭ majeur"]))
add("Franz Schubert", "Sérénade (Ständchen), D. 957 (transcription)", "piece", R, 3, "Lied")
mend_names = {(19, 6): " « Barcarolle vénitienne n° 1 »", (30, 6): " « Barcarolle vénitienne n° 2 »", (62, 3): " « Marche funèbre »", (62, 6): " « Chant du printemps »", (67, 4): " « La Fileuse »", (62, 5): " « Barcarolle vénitienne n° 3 »", (38, 6): " « Duetto »"}
col("Felix Mendelssohn", "Romances sans paroles (intégrale)", R, 4, "Romance", [f"Op. {op} n° {n}{mend_names.get((op, n), '')}" for op in (19, 30, 38, 53, 62, 67, 85, 102) for n in range(1, 7)])
col("Johannes Brahms", "Trois intermezzi, op. 117", R, 5, "Intermezzo", keyed("Intermezzo", ["mi♭ majeur","si♭ mineur","do♯ mineur"]))
col("Johannes Brahms", "Six Klavierstücke, op. 118", R, 5, "Pièce de caractère", ["1. Intermezzo en la mineur","2. Intermezzo en la majeur","3. Ballade en sol mineur","4. Intermezzo en fa mineur","5. Romance en fa majeur","6. Intermezzo en mi♭ mineur"])
col("Johannes Brahms", "Quatre Klavierstücke, op. 119", R, 5, "Pièce de caractère", ["1. Intermezzo en si mineur","2. Intermezzo en mi mineur","3. Intermezzo en do majeur","4. Rhapsodie en mi♭ majeur"])
col("Johannes Brahms", "16 Valses, op. 39", R, 4, "Valse", num(16, "Valse n° "))
col("Franz Liszt", "Consolations, S. 172", R, 4, "Pièce de caractère", keyed("Consolation", ["mi majeur","mi majeur","ré♭ majeur","ré♭ majeur","mi majeur","mi majeur"]))
col("Franz Liszt", "Rêves d'amour (Liebesträume), S. 541", R, 5, "Nocturne", ["Rêve d'amour n° 1 en la♭ majeur","Rêve d'amour n° 2 en mi majeur","Rêve d'amour n° 3 en la♭ majeur"])
col("Franz Liszt", "Études d'exécution transcendante, S. 139", R, 5, "Étude", [f"{i}. {t}" for i, t in enumerate(["Preludio","Molto vivace (la mineur)","Paysage","Mazeppa","Feux follets","Vision","Eroica","Wilde Jagd","Ricordanza","Allegro agitato molto (fa mineur)","Harmonies du soir","Chasse-neige"], 1)])
add("Franz Liszt", "La Campanella (Grande étude de Paganini n° 3)", "piece", R, 5, "Étude")
add("Franz Liszt", "Rhapsodie hongroise n° 2, S. 244/2", "piece", R, 5, "Rhapsodie")
col("Edvard Grieg", "Pièces lyriques, Livre I, op. 12", R, 2, "Pièce de caractère", [f"{i}. {t}" for i, t in enumerate(["Arietta","Valse","Chant du veilleur de nuit","Danse des elfes","Mélodie populaire","Mélodie norvégienne","Feuillet d'album","Chant national"], 1)])
col("Edvard Grieg", "Pièces lyriques, Livre III, op. 43", R, 4, "Pièce de caractère", [f"{i}. {t}" for i, t in enumerate(["Papillon","Voyageur solitaire","Dans mon pays","Petit oiseau","Poème érotique","Au printemps"], 1)])
col("Piotr Ilitch Tchaïkovski", "Les Saisons, op. 37a", R, 4, "Pièce de caractère", ["Janvier — Au coin du feu","Février — Carnaval","Mars — Chant de l'alouette","Avril — Perce-neige","Mai — Nuits blanches",
 "Juin — Barcarolle","Juillet — Chant du faucheur","Août — La moisson","Septembre — La chasse","Octobre — Chant d'automne","Novembre — Troïka","Décembre — Noël"])
col("Piotr Ilitch Tchaïkovski", "Album pour enfants, op. 39", R, 2, "Pièce de caractère", [f"{i}. {t}" for i, t in enumerate([
 "Prière du matin","Matin d'hiver","Le petit cavalier","Maman","Marche des soldats de bois","La poupée malade","Enterrement de la poupée","Valse","La nouvelle poupée","Mazurka","Chanson russe",
 "Le paysan joue de l'accordéon","Kamarinskaïa","Polka","Chanson italienne","Vieille chanson française","Chanson allemande","Chanson napolitaine","Conte de la nourrice","Baba Yaga",
 "Douce rêverie","Chant de l'alouette","Le joueur d'orgue de Barbarie","À l'église"], 1)])
col("Modeste Moussorgski", "Tableaux d'une exposition", R, 5, "Suite", ["Promenade","Gnomus","Il vecchio castello","Tuileries","Bydło","Ballet des poussins dans leurs coques","Samuel Goldenberg et Schmuÿle",
 "Limoges — Le marché","Catacombes","La cabane sur des pattes de poule (Baba Yaga)","La grande porte de Kiev"])
col("Sergueï Rachmaninov", "10 Préludes, op. 23", R, 5, "Prélude", keyed("Prélude", ["fa♯ mineur","si♭ majeur","ré mineur","ré majeur","sol mineur","mi♭ majeur","do mineur","la♭ majeur","mi♭ mineur","sol♭ majeur"]))
col("Sergueï Rachmaninov", "13 Préludes, op. 32", R, 5, "Prélude", keyed("Prélude", ["do majeur","si♭ mineur","mi majeur","mi mineur","sol majeur","fa mineur","fa majeur","la mineur","la majeur","si mineur","si majeur","sol♯ mineur","ré♭ majeur"]))
add("Sergueï Rachmaninov", "Prélude en do♯ mineur, op. 3 n° 2", "piece", R, 5, "Prélude")
col("Alexandre Scriabine", "24 Préludes, op. 11", R, 5, "Prélude", keyed("Prélude", pk))
col("Gabriel Fauré", "Dolly, op. 56 (piano à quatre mains)", R, 3, "Suite", ["Berceuse","Mi-a-ou","Le jardin de Dolly","Kitty-valse","Tendresse","Le pas espagnol"])
col("Gabriel Fauré", "Nocturnes (intégrale)", R, 5, "Nocturne", num(13, "Nocturne n° "))
col("Gabriel Fauré", "Barcarolles (intégrale)", R, 5, "Barcarolle", num(13, "Barcarolle n° "))
col("Isaac Albéniz", "España, op. 165", R, 4, "Suite", ["Preludio","Tango","Malagueña","Serenata","Capricho catalán","Zortzico"])
add("Isaac Albéniz", "Asturias (Leyenda)", "piece", R, 5, "Pièce de caractère")
col("Enrique Granados", "12 Danses espagnoles, op. 37", R, 4, "Danse", [f"Danse espagnole n° {i}" + (" « Andaluza »" if i == 5 else " « Oriental »" if i == 2 else "") for i in range(1, 13)])

# ───────── Moderne
col(DEB, "Children's Corner", M, 4, "Suite", ["Doctor Gradus ad Parnassum","Jimbo's Lullaby","Serenade for the Doll","The Snow Is Dancing","The Little Shepherd","Golliwogg's Cakewalk"])
col(DEB, "Suite bergamasque", M, 4, "Suite", ["Prélude","Menuet","Clair de lune","Passepied"])
col(DEB, "Deux arabesques", M, 4, "Arabesque", ["Arabesque n° 1 en mi majeur","Arabesque n° 2 en sol majeur"])
col(DEB, "Préludes, Livre I", M, 5, "Prélude", [f"{i}. {t}" for i, t in enumerate(["Danseuses de Delphes","Voiles","Le vent dans la plaine","« Les sons et les parfums tournent dans l'air du soir »","Les collines d'Anacapri",
 "Des pas sur la neige","Ce qu'a vu le vent d'ouest","La fille aux cheveux de lin","La sérénade interrompue","La cathédrale engloutie","La danse de Puck","Minstrels"], 1)])
col(DEB, "Préludes, Livre II", M, 5, "Prélude", [f"{i}. {t}" for i, t in enumerate(["Brouillards","Feuilles mortes","La puerta del Vino","« Les fées sont d'exquises danseuses »","Bruyères","« General Lavine » — eccentric",
 "La terrasse des audiences du clair de lune","Ondine","Hommage à S. Pickwick Esq. P.P.M.P.C.","Canope","Les tierces alternées","Feux d'artifice"], 1)])
col(DEB, "Estampes", M, 5, "Suite", ["Pagodes","La soirée dans Grenade","Jardins sous la pluie"])
col(DEB, "Images, Livre I", M, 5, "Suite", ["Reflets dans l'eau","Hommage à Rameau","Mouvement"])
col(DEB, "Images, Livre II", M, 5, "Suite", ["Cloches à travers les feuilles","Et la lune descend sur le temple qui fut","Poissons d'or"])
col(DEB, "Pour le piano", M, 5, "Suite", ["Prélude","Sarabande","Toccata"])
add(DEB, "Clair de lune (Suite bergamasque)", "piece", M, 4, "Pièce de caractère")
add(DEB, "Rêverie", "piece", M, 3, "Pièce de caractère")
add(DEB, "La fille aux cheveux de lin", "piece", M, 3, "Prélude")
add(DEB, "Le petit nègre", "piece", M, 2, "Pièce de caractère")
add(DEB, "L'Isle joyeuse", "piece", M, 5, "Pièce de caractère")
col("Erik Satie", "Trois Gymnopédies", M, 2, "Pièce de caractère", ["Gymnopédie n° 1 — Lent et douloureux","Gymnopédie n° 2 — Lent et triste","Gymnopédie n° 3 — Lent et grave"])
col("Erik Satie", "Gnossiennes", M, 3, "Pièce de caractère", num(6, "Gnossienne n° "))
add("Erik Satie", "Je te veux", "piece", M, 3, "Valse")
col("Maurice Ravel", "Miroirs", M, 5, "Suite", ["Noctuelles","Oiseaux tristes","Une barque sur l'océan","Alborada del gracioso","La vallée des cloches"])
col("Maurice Ravel", "Le Tombeau de Couperin", M, 5, "Suite", ["Prélude","Fugue","Forlane","Rigaudon","Menuet","Toccata"])
col("Maurice Ravel", "Gaspard de la nuit", M, 5, "Suite", ["Ondine","Le Gibet","Scarbo"])
col("Maurice Ravel", "Ma mère l'Oye (piano à quatre mains)", M, 3, "Suite", ["Pavane de la Belle au bois dormant","Petit Poucet","Laideronnette, impératrice des pagodes","Les entretiens de la Belle et de la Bête","Le jardin féerique"])
col("Maurice Ravel", "Sonatine", M, 5, "Sonatine", ["I. Modéré","II. Mouvement de menuet","III. Animé"])
add("Maurice Ravel", "Pavane pour une infante défunte", "piece", M, 4, "Pavane")
col("Béla Bartók", "Mikrokosmos, volume 1 (n° 1-36)", M, 1, "Pièce pédagogique", num(36))
col("Béla Bartók", "Mikrokosmos, volume 2 (n° 37-66)", M, 1, "Pièce pédagogique", num(30, start=37))
col("Béla Bartók", "Mikrokosmos, volume 3 (n° 67-96)", M, 2, "Pièce pédagogique", num(30, start=67))
col("Béla Bartók", "Mikrokosmos, volume 4 (n° 97-121)", M, 3, "Pièce pédagogique", num(25, start=97))
col("Béla Bartók", "Mikrokosmos, volume 5 (n° 122-139)", M, 4, "Pièce pédagogique", num(18, start=122))
col("Béla Bartók", "Mikrokosmos, volume 6 (n° 140-153)", M, 5, "Pièce pédagogique", num(14, start=140))
col("Béla Bartók", "Pour les enfants, volume 1 (mélodies hongroises)", M, 2, "Pièce pédagogique", num(40))
col("Béla Bartók", "Pour les enfants, volume 2 (mélodies slovaques)", M, 2, "Pièce pédagogique", num(39))
col("Béla Bartók", "Danses populaires roumaines, Sz. 56", M, 4, "Danse", ["1. Danse du bâton","2. Danse du châle","3. Sur place","4. Danse de Bucsum","5. Polka roumaine","6. Danse rapide"])
col("Dmitri Kabalevski", "24 Pièces pour enfants, op. 39", M, 1, "Pièce pédagogique", num(24))
col("Dmitri Kabalevski", "30 Pièces pour enfants, op. 27", M, 2, "Pièce pédagogique", num(30))
col("Sergueï Prokofiev", "Musiques d'enfants, op. 65", M, 3, "Pièce de caractère", [f"{i}. {t}" for i, t in enumerate(["Matin","Promenade","Historiette","Tarentelle","Repentir","Valse","Cortège de sauterelles",
 "La pluie et l'arc-en-ciel","Jeu de chat","Marche","Soir","Sur les prés la lune se promène"], 1)])
col("Sergueï Prokofiev", "Visions fugitives, op. 22", M, 5, "Pièce de caractère", num(20))
col("Dmitri Chostakovitch", "24 Préludes et fugues, op. 87", M, 5, "Prélude et fugue", num(24, "Prélude et fugue n° "))
col("Francis Poulenc", "Trois mouvements perpétuels", M, 4, "Pièce de caractère", ["I. Assez modéré","II. Très modéré","III. Alerte"])
add("Francis Poulenc", "Improvisation n° 15 « Hommage à Édith Piaf »", "piece", M, 4, "Improvisation")
col("George Gershwin", "Trois préludes", M, 5, "Prélude", num(3, "Prélude n° "))
add("Scott Joplin", "The Entertainer", "piece", M, 3, "Ragtime")
add("Scott Joplin", "Maple Leaf Rag", "piece", M, 4, "Ragtime")
add("Aram Khatchatourian", "Toccata", "piece", M, 5, "Toccata")

# ───────── Contemporain / musiques de film
col("Ludovico Einaudi", "Una mattina (album)", K, 3, "Néoclassique", ["Una mattina","Ora","Resta con me","Leo","A fuoco","Dolce droga","Dietro casa","Come un fiore","DNA","Nuvole nere","Questa volta","Nuvole bianche","Ancora"])
for t, l in [("Nuvole bianche", 3), ("Una mattina", 2), ("I giorni", 3), ("Le onde", 3), ("Experience", 3), ("Divenire", 4), ("Primavera", 4), ("Fly", 3)]:
    add("Ludovico Einaudi", t, "piece", K, l, "Néoclassique")
for t, l in [("Comptine d'un autre été : l'après-midi", 2), ("La valse d'Amélie", 3), ("La dispute", 2), ("Le moulin", 3), ("Sur le fil", 4)]:
    add("Yann Tiersen", t, "piece", K, l, "Musique de film")
add("Yiruma", "River Flows in You", "piece", K, 3, "Néoclassique")
add("Yiruma", "Kiss the Rain", "piece", K, 3, "Néoclassique")
add("Joe Hisaishi", "Merry-Go-Round of Life (Le Château ambulant)", "piece", K, 4, "Musique de film")
add("Joe Hisaishi", "One Summer's Day (Le Voyage de Chihiro)", "piece", K, 3, "Musique de film")
add("Joe Hisaishi", "Summer (L'Été de Kikujiro)", "piece", K, 3, "Musique de film")
col("Philip Glass", "Metamorphosis", K, 3, "Minimalisme", [f"Metamorphosis {r}" for r in ("One", "Two", "Three", "Four", "Five")])
col("Philip Glass", "Études, Livre I (n° 1-10)", K, 4, "Étude", num(10, "Étude n° "))
col("Philip Glass", "Études, Livre II (n° 11-20)", K, 5, "Étude", num(10, "Étude n° ", 11))
add("Philip Glass", "Opening (Glassworks)", "piece", K, 3, "Minimalisme")
add("Michael Nyman", "The Heart Asks Pleasure First (La Leçon de piano)", "piece", K, 4, "Musique de film")
add("Max Richter", "Written on the Sky", "piece", K, 2, "Néoclassique")
add("Arvo Pärt", "Für Alina", "piece", K, 2, "Minimalisme")
add("Hans Zimmer", "Time (Inception)", "piece", K, 2, "Musique de film")
add("Hans Zimmer", "Interstellar — Main Theme", "piece", K, 3, "Musique de film")
add("John Williams", "Hedwig's Theme (Harry Potter)", "piece", K, 3, "Musique de film")
add("Ennio Morricone", "Le Clan des Siciliens (thème)", "piece", K, 3, "Musique de film")
add("Vladimir Cosma", "Le Grand Blond avec une chaussure noire (thème)", "piece", K, 3, "Musique de film")

# ───────── Chanson, pop, jazz
for c, t, l in [("John Lennon", "Imagine", 2), ("The Beatles", "Let It Be", 2), ("The Beatles", "Yesterday", 2), ("The Beatles", "Hey Jude", 2), ("Leonard Cohen", "Hallelujah", 2),
                ("Queen", "Bohemian Rhapsody", 4), ("Elton John", "Your Song", 3), ("Adele", "Someone Like You", 2), ("Coldplay", "Clocks", 3), ("Coldplay", "The Scientist", 2),
                ("Michel Berger", "Le Paradis blanc", 3), ("Véronique Sanson", "Amoureuse", 3), ("Jacques Brel", "Ne me quitte pas", 3), ("Édith Piaf", "La Vie en rose", 2),
                ("Charles Aznavour", "La Bohème", 3), ("Barbara", "L'Aigle noir", 3), ("Francis Cabrel", "Je l'aime à mourir", 2), ("Yann Tiersen", "Porz Goret", 4),
                ("Billy Joel", "Piano Man", 3), ("Alicia Keys", "If I Ain't Got You", 3), ("Lady Gaga", "Shallow", 2), ("Erroll Garner", "Misty", 4), ("Bill Evans", "Waltz for Debby", 5),
                ("Dave Brubeck", "Take Five", 4), ("Vince Guaraldi", "Linus and Lucy", 3), ("Justin Hurwitz", "Mia & Sebastian's Theme (La La Land)", 3)]:
    add(c, t, "piece", P, l, "Jazz" if c in ("Erroll Garner", "Bill Evans", "Dave Brubeck", "Vince Guaraldi") else "Chanson")

# ───────── Méthodes
met("Ernest Van de Velde", "Méthode Rose (1re année de piano)", 1)
met("Ernest Van de Velde", "Le Déliateur", 2)
met("Charles Hervé & Jacqueline Pouillard", "Méthode de piano débutants", 1)
met("Christophe Astié", "Le Piano pour adulte débutant", 1)
met("Palmer, Manus & Lethco", "Alfred's Basic Adult Piano Course, Level 1", 1)
met("Palmer, Manus & Lethco", "Alfred's Basic Adult Piano Course, Level 2", 2)
met("Nancy & Randall Faber", "Adult Piano Adventures, Book 1", 1)
met("Nancy & Randall Faber", "Adult Piano Adventures, Book 2", 2)
met("John Thompson", "Easiest Piano Course, Part 1", 1)
met("James Bastien", "Bastien Piano Basics, Level 1", 1)
for v in range(1, 8):
    met("Shinichi Suzuki", f"Suzuki Piano School, volume {v}", min(5, 1 + v // 2))
add("Divers compositeurs", "Les Classiques favoris du piano, volume 1", "collection", None, 2, "Recueil")
add("Divers compositeurs", "Les Classiques favoris du piano, volume 2", "collection", None, 3, "Recueil")

ids = set()
for it in ITEMS:
    base, i = it["id"][:80], 2
    it["id"] = base
    while it["id"] in ids:
        it["id"] = f"{base}-{i}"; i += 1
    ids.add(it["id"])
    for k in [k for k, v in it.items() if v is None]: del it[k]

out = os.path.join(os.path.dirname(__file__), "..", "PianoJournal", "Resources", "catalog.json")
json.dump(ITEMS, open(out, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
n_pieces = sum(len(i.get("pieces", [])) for i in ITEMS)
print(len(ITEMS), "entrées,", sum(1 for i in ITEMS if i["kind"] != "piece"), "recueils/méthodes,", n_pieces, "pièces en sous-chapitres,", len({i['composer'] for i in ITEMS}), "compositeurs")
