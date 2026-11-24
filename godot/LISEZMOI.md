# Sécurité de nuit 3D — projet Godot 4 (jumahestudi)

Prototype de la version Godot : **Le Néon**, la porte puis la salle, l'agent en 3e personne.
Toute la logique du jeu (contrôle à la porte, liste noire, testing, mineurs, armes, incidents en salle,
radio, bilan juridique) est branchée. Les personnages et le décor sont **provisoires** (formes simples),
en attendant les vrais modèles 3D.

## Lancer le jeu

1. Installe **Godot 4.3 ou plus récent** (version « Standard », pas .NET) : https://godotengine.org/download
2. Dézippe ce dossier.
3. Ouvre Godot → **Importer** → choisis le fichier `project.godot` → **Importer et modifier**.
4. Appuie sur **F5** (ou le bouton ▶ en haut à droite).

Au premier lancement, Godot peut mettre quelques secondes à importer les fichiers.

## Commandes

| Touche | Action |
|---|---|
| Z Q S D (ou W A S D, flèches) | Se déplacer |
| Souris | Regarder (clique d'abord dans le jeu) |
| Maj | Courir |
| E | Contrôler un client / intervenir / observer |
| R | Radio : envoyer Moussa ou Sarah sur un incident (en salle) |
| Échap | Fermer le panneau / libérer la souris |

## Si ça ne marche pas

En bas de l'éditeur, onglet **Débogueur** (ou **Sortie**) : copie le message d'erreur en rouge
et envoie-le-moi tel quel, avec le nom du fichier et le numéro de ligne. Je corrige.

## Organisation

```
project.godot          configuration du projet
scenes/Main.tscn       scène principale (tout est construit par le code)
scripts/data.gd        données (chargées automatiquement) : noms, apparences, liste noire, motifs
scripts/main.gd        la partie : porte, salle, incidents, radio, bilan
scripts/world.gd       le décor du Néon (rue, file, façade, hall, piste LED, bar, VIP, fumoir, WC)
scripts/person.gd      les personnages et leurs animations
scripts/ui.gd          l'interface (HUD, panneaux, écrans)
data/incidents.json    les 103 incidents de la version web (textes, choix, lois, faits réels)
data/door_events.json  les 46 événements de porte (pour la prochaine étape)
data/gerant.json       les appels du gérant (pour la prochaine étape)
assets/characters/     les vrais personnages 3D (hommes/, femmes/, agents/)
assets/animations/     leurs animations (Idle.fbx, Walk.fbx…)
```

## Vrais personnages réalistes (Mixamo, gratuit)

> **Ta sélection actuelle est déjà décrite** dans `assets/characters/personnages.json`
> (Remy, Ch02, Ch06, Ch12, Ch26, Ch27, Ch33, Ch37 + Ch18 comme agent).
> Pas besoin de renommer quoi que ce soit : mets tous les personnages dans `assets/characters/`
> et toutes les animations (Idle, Walking, Running, Hip_Hop_Dancing, Dying, Talking, Punching_Bag)
> dans `assets/animations/`, avec leurs noms d'origine.

Le jeu remplace automatiquement les personnages provisoires par les vrais dès que tu mets des fichiers
dans les bons dossiers. Tu peux en mettre peu au début (2 hommes, 2 femmes, 1 agent) et en ajouter ensuite.

### 1. Créer un compte
Va sur **https://www.mixamo.com** et connecte-toi avec un compte Adobe (gratuit).

### 2. Télécharger les personnages
Onglet **Characters** : choisis un personnage, puis **Download** avec ces réglages :
- Format : **FBX Binary (.fbx)**
- Pose : **T-pose**

Range chaque fichier selon le personnage :

| Dossier | Quoi | Conseil |
|---|---|---|
| `godot/assets/characters/hommes/` | clients hommes | 4 à 8 personnages variés (âges, tenues, origines) |
| `godot/assets/characters/femmes/` | clientes femmes | 4 à 8 personnages variés |
| `godot/assets/characters/agents/` | toi et tes collègues | 1 ou 2 personnages en tenue sombre |

Donne-leur des noms simples : `homme1.fbx`, `femme1.fbx`, `agent1.fbx`…

### 3. Télécharger les animations
Garde **un seul personnage** sélectionné, onglet **Animations**. Pour chaque ligne : tape le mot dans la
recherche, choisis une animation qui ressemble, coche **In Place** quand la case existe, puis **Download** :
- Format : **FBX Binary (.fbx)**
- Skin : **Without Skin**
- Frames per second : **30**

Renomme le fichier **exactement** comme dans la 1re colonne et range-le dans `godot/assets/animations/` :

| Nom du fichier | À chercher sur Mixamo | Obligatoire ? |
|---|---|---|
| `Idle.fbx` | Idle | oui |
| `Walk.fbx` | Walking (In Place) | oui |
| `Run.fbx` | Running (In Place) | oui |
| `Dance.fbx` | Dancing / Hip Hop Dancing | oui |
| `Fight.fbx` | Fighting Idle / Boxing | oui |
| `Fall.fbx` | Falling Back Death / Dying | oui |
| `Talk.fbx` | Talking | conseillé |
| `Drink.fbx` | Drinking | facultatif |
| `Phone.fbx` | Talking On Phone | facultatif |
| `Sit.fbx` | Sitting Idle | facultatif |
| `Surrender.fbx` | Surrender | facultatif |
| `Punching.fbx` | Punching | **baston** |
| `Hit_Reaction.fbx` | Hit Reaction / Head Hit | **baston** |
| `Center_Block.fbx` | Center Block / Body Block | **baston** |
| `Kneeling_Idle.fbx` | Kneeling Idle | **baston** (personne maîtrisée) |
| `Pushing.fbx` | Push / Pushing | baston, facultatif |

Toutes les animations Mixamo marchent sur tous les personnages Mixamo : un seul jeu d'animations suffit.

### 4. (Facultatif) Décrire les personnages
Pour que la **photo de la pièce d'identité** et la **liste noire** collent aux vrais visages, copie
`assets/characters/personnages.exemple.json` en `personnages.json` et décris chaque fichier
(peau, cheveux, coiffure). Si tu remplis **« signe »** pour au moins 2 personnages
(ex. « barbe épaisse, veste en cuir rouge »), ce sont eux qui seront sur la liste noire.

### 5. Lancer
Ouvre le projet dans Godot : il importe les nouveaux fichiers (ça peut prendre une minute), puis **F5**.
En bas, dans **Sortie**, une ligne indique ce qui a été trouvé, par exemple :
`Personnages : 4 hommes, 4 femmes, 1 agent · animations : Idle, Walk, Run…`
Copie-moi cette ligne et les éventuelles erreurs en rouge.

> Les fichiers Mixamo ne sont **pas envoyés sur GitHub** (ils sont exclus par `.gitignore`) :
> la licence Adobe autorise leur usage dans ton jeu, mais pas leur redistribution telle quelle.

## Feuille de route

1. ✅ Le Néon, porte + salle, incidents, radio, bilan
2. 🔄 Vrais personnages animés (Mixamo) — code prêt, à toi de télécharger les fichiers
3. ✅ Mode baston (coups, garde, esquive, saisie, renfort, légitime défense)
4. Décor réaliste (Kenney / Quaternius)
5. Carrière : vestiaire, habitués (Kévin, Lucas, Nadia…), événements de porte, gérant, équipement
6. Les autres établissements (Le Comptoir, Le Palace, L'Usine)
7. Son et musique, minicarte, export en .exe
