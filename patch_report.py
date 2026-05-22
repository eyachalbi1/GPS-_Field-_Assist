import re

with open('sprint1_report_improved.tex', 'r', encoding='utf-8') as f:
    content = f.read()

# Patch 1: Ajouter explication backlog + modifier raffinement
pattern1 = r"(\\caption\\{Backlog Sprint 1 - 12/12 .lements impl.men.es \\(100%\\)\\}\\n\\\\label\\{tab:backlog\\}\\n\\\\end\\{table\\}\\n\\n% =+\\n\\\\subsection\\{Raffinement des cas d'utilisation\\}\\n% =+\\n\\nLa pr.sente section d.taille le raffinement des cas d'utilisation principaux, incluant le diagramme de cas d'utilisation et le tableau des acteurs\\.\\n\\n\\\\subsubsection\\{Diagramme de cas d'utilisation - GPS Field Assist\\}\\n\\nLa figure \\\\ref\\{fig:usecase-global\\} pr.sente le diagramme de cas d'utilisation global du syst.me \\\\textbf\\{GPS Field Assist\\} impl.men. lors du Sprint 1\\. Ce diagramme est d.fini dans le fichier \\\\texttt\\{sprint1_usecase_diagram_v2\\.puml\\} au format PlantUML\\.\\n\\n\\\\begin\\{figure\\}\\[H\\]\\n\\\\centering\\n% G.n.r. depuis sprint1_usecase_diagram_v2\\.puml\\n% Commande: plantuml -tpng sprint1_usecase_diagram_v2\\.puml -o \\./\\n% Note: L'image doit .tre dans le m.me r.pertoire que le \\.tex ou ajuster le chemin\\n\\\\includegraphics\\[width=0\\.95\\\\textwidth\\]\\{sprint1_usecase_diagram_v2\\.png\\}\\n\\\\caption\\{Diagramme de cas d'utilisation - GPS Field Assist Sprint 1\\}\\n\\\\label\\{fig:usecase-global\\}\\n\\\\end\\{figure\\}\\n\\n\\\\textbf\\{Description du diagramme :\\}\\n\\nLe diagramme identifie 5 acteurs principaux et leurs interactions avec le syst.me\\. Il montre les relations d'inclusion et d'extension entre les diff.rents cas d'utilisation\\. Le c.ur du syst.me est le diagnostic s.quentiel, qui inclut obligatoirement l'envoi de SMS, le polling de la bo.te de r.ception, le parsing des r.ponses et le stockage dans l'historique\\. D'autres cas d'utilisation .tendent ce workflow de base selon les besoins \\(r.cup.ration IMEI, diagnostics alternatifs, retry APN, alertes pr.dictives\\)\\.\\n)"

replacement1 = r"""\caption{Backlog Sprint 1 - 12/12 elements implementes (100\%)}
\label{tab:backlog}
\end{table}

\textbf{Explication du tableau du Backlog :}

Ce tableau liste les 12 elements du backlog du Sprint 1, tous marques comme \textbf{termines} (100\% de realisation). Les elements 1--4 concernent les fonctionnalites core (SMS, diagnostic, configuration APN, mise a jour firmware). Les elements 5--8 couvrent les services transversaux (prediction GPS, historique, monitoring SMS, UI visuelle). Les elements 9--12 traitent de la qualite et de la robustesse (tests terrain, documentation, cache offline, gestion timeouts/retry).

% =============================================================================
\subsection{Raffinement des cas d'utilisation}
% =============================================================================

La presente section detaille le raffinement des cas d'utilisation selon une approche de \textbf{decomposition hierarchique}. Le systeme est decrit a travers un \textbf{diagramme global} (vue d'ensemble) puis cinq \textbf{diagrammes detailles} par module fonctionnel (Diagnostic, Configuration, Mise a jour, Position GPS, Statistiques). Chaque diagramme detaille presente les commandes SMS exactes utilisees dans le code source du projet.

\subsubsection{Diagramme de cas d'utilisation global --- GPS Field Assist}

La figure \ref{fig:usecase-global} presente la vue d'ensemble du systeme avec les 5 acteurs principaux et les cas d'utilisation agreges par module fonctionnel.

\begin{figure}[H]
\centering
\includegraphics[width=0.95\textwidth]{sprint1_usecase_diagram_v2.png}
\caption{Diagramme de cas d'utilisation global --- GPS Field Assist Sprint 1}
\label{fig:usecase-global}
\end{figure}

\textbf{Explication du diagramme global :} Ce diagramme identifie 5 acteurs principaux (Technicien, Boitier GPS, Operateur Mobile, Backend API, Systeme SMS) et 5 modules fonctionnels regroupes en packages : Diagnostic, Configuration APN, Mise a jour Firmware, Position GPS et Statistiques. Les relations \texttt{<<include>>} indiquent les dependances obligatoires et les \texttt{<<extend>>} representent les extensions conditionnelles (retry APN si echec, correction automatique si anomalie)."""

result1, count1 = re.subn(pattern1, replacement1, content, count=1)
if count1 > 0:
    content = result1
    print("Patch 1 OK")
else:
    print("Patch 1 FAILED")

# Patch 2: Tableau acteurs + sequence
pattern2 = r"(\\\\caption\\{Tableau des acteurs principaux du syst.me GPS Field Assist\\}\\n\\\\label\\{tab:actors\\}\\n\\\\end\\{table\\}\\n\\n\\\\subsubsection\\{Diagramme de s.quence - Diagnostic s.quentiel ET8\\})"

replacement2 = r"""\caption{Tableau des acteurs principaux du systeme GPS Field Assist}
\label{tab:actors}
\end{table}

\textbf{Explication du tableau des acteurs :} Ce tableau definit les 5 acteurs qui interagissent avec le systeme GPS Field Assist. Le \textbf{Technicien Terrain} est l'utilisateur principal qui pilote l'application mobile Flutter. Le \textbf{Backend API} (Node.js + PostgreSQL) sert de passerelle avec la plateforme Odoo. L'\textbf{Operateur Mobile} fournit l'infrastructure GSM pour la transmission des SMS. Le \textbf{Systeme SMS} represente l'API Telephony de l'appareil mobile. Les \textbf{Boitiers GPS} sont les equipements terrain qui executent les commandes SMS.

\subsubsection{Diagramme de sequence - Diagnostic sequentiel multi-modules}"""

result2, count2 = re.subn(pattern2, replacement2, content, count=1)
if count2 > 0:
    content = result2
    print("Patch 2 OK")
else:
    print("Patch 2 FAILED")

with open('sprint1_report_improved.tex', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
