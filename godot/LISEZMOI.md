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
assets/characters/     ici iront les vrais personnages 3D
```

## Étape suivante : de vrais personnages

Le code est déjà prêt : s'il trouve `assets/characters/human.glb`, il l'utilise à la place des
personnages provisoires. Il cherche ces animations dans le fichier :
`Idle`, `Walk`, `Run`, `Dance`, `Fight`, `Fall`, `Sit`, `Talk`, `Surrender`.

Sources gratuites : **Mixamo** (personnages + animations, compte Adobe gratuit),
**Quaternius** et **Kenney** (décors, mobilier, voitures, licence libre).
On fera ce branchement ensemble à l'étape suivante.

## Feuille de route

1. ✅ Le Néon, porte + salle, incidents, radio, bilan
2. Vrais personnages animés (Mixamo) et décor réaliste
3. Mode baston (coups, garde, esquive, saisie, légitime défense)
4. Carrière : vestiaire, habitués (Kévin, Lucas, Nadia…), événements de porte, gérant, équipement
5. Les autres établissements (Le Comptoir, Le Palace, L'Usine)
6. Son et musique, minicarte, export en .exe
