# Diagrammes GPS Field Assist

Ce dossier contient les diagrammes UML ameliores du projet GPS Field Assist.

## Structure

```
diagrammes/
├── use_case_main.puml          # Cas d'utilisation complet (reference)
├── use_case_overview.puml      # Cas d'utilisation simplifie (rapports)
├── sequence_main.puml          # Sequence detaille avec ref/loop/alt
├── sequence_overview.puml      # Sequence vue d'ensemble
├── generated/                  # Images PNG/SVG generees
└── archive/                    # Anciens diagrammes (backup)
```

## Generation des images

### Methode 1 : Plugin VSCode (recommande)
1. Installer l'extension **PlantUML** (jebbs.plantuml)
2. Ouvrir un fichier `.puml`
3. `Alt+D` pour previsualiser
4. Clic droit -> **Export Current Diagram** -> PNG/SVG

### Methode 2 : Ligne de commande (Java requis)
```bash
# Generer tous les diagrammes en PNG
for f in *.puml; do
  java -jar plantuml.jar -tpng "$f"
done

# Ou un seul fichier
java -jar plantuml.jar -tpng use_case_main.puml
```

### Methode 3 : Site web
1. Copier le contenu du fichier `.puml`
2. Coller sur [www.planttext.com](https://www.planttext.com)
3. Telecharger l'image generee

## Ameliorations apportees

| Aspect | Avant | Apres |
|--------|-------|-------|
| **Nombre fichiers** | 8+ redondants | 4 coherents |
| **Relations UC** | Relations incorrectes (acteur->UC avec extend) | Corrigees selon norme UML |
| **Sequence** | 7 etapes repetees (illisible) | Factorisees avec `ref` |
| **Gestion erreurs** | Absente | `loop` retry + `alt` correction |
| **Style** | Emojis inconsistants | Couleurs professionnelles |
| **Syntaxe** | Erreurs (UC sync, destroy dans loop) | Valide PlantUML |

## Integration LaTeX

Dans le rapport `.tex`, utiliser :
```latex
\begin{figure}[H]
\centering
\includegraphics[width=\textwidth]{diagrammes/generated/use_case_main.png}
\caption{Diagramme de cas d'utilisation - Sprint 1}
\label{fig:uc-main}
\end{figure}
```

