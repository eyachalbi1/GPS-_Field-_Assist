import shutil

# Restaurer le backup
shutil.copy('sprint1_report_improved_backup.tex', 'sprint1_report_improved.tex')

with open('sprint1_report_improved.tex', 'r', encoding='utf-8') as f:
    content = f.read()

# Modification 1: Ajouter explication après tableau user stories
old1 = '\\caption{User Stories du Sprint 1 - Points Fibonacci avec crit\\`eres d\\'etaill\\'es}'
new1 = old1 + '\n\\label{tab:user-stories}\n\n\\textbf{Explication du tableau des User Stories :}\n\nCe tableau pr\\'esente les 6 user stories s\\'electionn\\'ees pour le Sprint 1, totalisant 32 points selon la suite de Fibonacci. Chaque user story est accompagn\\'ee de crit\\`eres d\\'acceptation mesurables. \\textbf{US-01} (5 points) couvre l\\'envoi de commandes SMS diagnostiques avec retry et parsing automatique. \\textbf{US-02} (3 points) traite de la configuration APN simplifi\\'ee en 1 clic. \\textbf{US-03} (8 points) g\\`ere la mise \\`a jour firmware avec barre de progression. \\textbf{US-04} (5 points) concerne la localisation GPS avec int\\'egration cartographique. \\textbf{US-05} (8 points) d\\'ecrit le workflow s\\'equentiel guid\\'e avec corrections automatiques. \\textbf{US-06} (3 points) fournit les statistiques du parc avec 5 niveaux de statut pr\\'edictif.'
content = content.replace(old1, new1)

# Modification 2: Ajouter explication après tableau backlog
old2 = '\\caption{Backlog Sprint 1 - 12/12 \\'el\\'ements impl\\'ement\\'es (100\\%)}'
new2 = old2 + '\n\\label{tab:backlog}\n\n\\textbf{Explication du tableau du Backlog :}\n\nCe tableau liste les 12 \\'el\\'ements du backlog du Sprint 1, tous marqu\\'es comme \\textbf{termin\\'es} (100\\% de r\\'ealisation). Les \\'el\\'ements 1--4 concernent les fonctionnalit\\'es core (SMS, diagnostic, configuration APN, mise \\`a jour firmware). Les \\'el\\'ements 5--8 couvrent les services transversaux (pr\\'ediction GPS, historique, monitoring SMS, UI visuelle). Les \\'el\\'ements 9--12 traitent de la qualit\\'e et de la robustesse (tests terrain, documentation, cache offline, gestion timeouts/retry).'
content = content.replace(old2, new2)

# Modification 3: Remplacer la section raffinement des cas d'utilisation
old3 = """% =============================================================================
\\subsection{Raffinement des cas d'utilisation}
% =============================================================================

La pr\\'esente section d\\'etaille le raffinement des cas d'utilisation principaux, incluant le diagramme de cas d'utilisation et le tableau des acteurs.

\\subsubsection{Diagramme de cas d'utilisation - GPS Field Assist}

La figure \\ref{fig:usecase-global} pr\\'esente le diagramme de cas d'utilisation global du syst\\`eme \\textbf{GPS Field Assist} impl\\'ement\\'e lors du Sprint 1. Ce diagramme est d\\'efini dans le fichier \\texttt{sprint1\\_usecase\\_diagram\\_v2.puml} au format PlantUML.

\\begin{figure}[H]
\\centering
% G\\'en\\'er\\'e depuis sprint1_usecase_diagram_v2.puml
% Commande: plantuml -tpng sprint1_usecase_diagram_v2.puml -o ./
% Note: L'image doit \\^etre dans le m\\^eme r\\'epertoire que le .tex ou ajuster le chemin
\\includegraphics[width=0.95\\textwidth]{sprint1_usecase_diagram_v2.png}
\\caption{Diagramme de cas d'utilisation - GPS Field Assist Sprint 1}
\\label{fig:usecase-global}
\\end{figure}

\\textbf{Description du diagramme :}

Le diagramme identifie 5 acteurs principaux et leurs interactions avec le syst\\`eme. Il montre les relations d'inclusion et d'extension entre les diff\\'erents cas d'utilisation. Le c\\oe ur du syst\\`eme est le diagnostic s\\'equentiel, qui inclut obligatoirement l'envoi de SMS, le polling de la bo\\^ite de r\\'eception, le parsing des r\\'eponses et le stockage dans l'historique. D'autres cas d'utilisation \\'etendent ce workflow de base selon les besoins (r\\'ecup\\'eration IMEI, diagnostics alternatifs, retry APN, alertes pr\\'edictives)."""

new3 = """% =============================================================================
\\subsection{Raffinement des cas d'utilisation}
% =============================================================================

La pr\\'esente section d\\'etaille le raffinement des cas d'utilisation selon une approche de \\textbf{d\\'ecomposition hi\\'erarchique}. Le syst\\`eme est d\\'ecrit \\`a travers un \\textbf{diagramme global} (vue d'ensemble) puis cinq \\textbf{diagrammes d\\'etaill\\'es} par module fonctionnel (Diagnostic, Configuration, Mise \\`a jour, Position GPS, Statistiques). Chaque diagramme d\\'etaill\\'e pr\\'esente les commandes SMS exactes utilis\\'ees dans le code source du projet.

\\subsubsection{Diagramme de cas d'utilisation global --- GPS Field Assist}

La figure \\ref{fig:usecase-global} pr\\'esente la vue d'ensemble du syst\\`eme avec les 5 acteurs principaux et les cas d'utilisation agr\\'eg\\'es par module fonctionnel.

\\begin{figure}[H]
\\centering
\\includegraphics[width=0.95\\textwidth]{sprint1_usecase_diagram_v2.png}
\\caption{Diagramme de cas d'utilisation global --- GPS Field Assist Sprint 1}
\\label{fig:usecase-global}
\\end{figure}

\\textbf{Explication du diagramme global :} Ce diagramme identifie 5 acteurs principaux (Technicien, Bo\\^itier GPS, Op\\'erateur Mobile, Backend API, Syst\\`eme SMS) et 5 modules fonctionnels regroup\\'es en packages : Diagnostic, Configuration APN, Mise \\`a jour Firmware, Position GPS et Statistiques. Les relations \\texttt{<<include>>} indiquent les d\\'ependances obligatoires (ex: tout diagnostic inclut l'envoi de SMS) et les \\texttt{<<extend>>} repr\\'esentent les extensions conditionnelles (ex: retry APN si \\'echec, correction automatique si anomalie)."""

content = content.replace(old3, new3)

with open('sprint1_report_improved.tex', 'w', encoding='utf-8') as f:
    f.write(content)

print('Modifications 1-3 appliquées avec succès')
