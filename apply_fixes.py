# -*- coding: utf-8 -*-
import shutil

# Restaurer le backup
shutil.copy('sprint1_report_improved_backup.tex', 'sprint1_report_improved.tex')

with open('sprint1_report_improved.tex', 'r', encoding='utf-8') as f:
    content = f.read()

# ======================= MOD 1: Explication User Stories =======================
old1 = r"""\label{tab:user-stories}
\end{table}

% =============================================================================
\subsection{Backlog du Sprint}"""
new1 = r"""\label{tab:user-stories}
\end{table}

\textbf{Explication du tableau des User Stories :}

Ce tableau presente les 6 user stories selectionnees pour le Sprint 1, totalisant 32 points selon la suite de Fibonacci. Chaque user story est accompagnee de criteres d'acceptation mesurables. \textbf{US-01} (5 points) couvre l'envoi de commandes SMS diagnostiques avec retry et parsing automatique. \textbf{US-02} (3 points) traite de la configuration APN simplifiee en 1 clic. \textbf{US-03} (8 points) gere la mise a jour firmware avec barre de progression. \textbf{US-04} (5 points) concerne la localisation GPS avec integration cartographique. \textbf{US-05} (8 points) decrit le workflow sequentiel guide avec corrections automatiques. \textbf{US-06} (3 points) fournit les statistiques du parc avec 5 niveaux de statut predictif.

% =============================================================================
\subsection{Backlog du Sprint}"""
content = content.replace(old1, new1)
print("MOD 1: User Stories OK")

# ======================= MOD 2: Explication Backlog =======================
old2 = r"""\label{tab:backlog}
\end{table}

% =============================================================================
\subsection{Raffinement des cas d'utilisation}"""
new2 = r"""\label{tab:backlog}
\end{table}

\textbf{Explication du tableau du Backlog :}

Ce tableau liste les 12 elements du backlog du Sprint 1, tous marques comme \textbf{termines} (100\% de realisation). Les elements 1--4 concernent les fonctionnalites core (SMS, diagnostic, configuration APN, mise a jour firmware). Les elements 5--8 couvrent les services transversaux (prediction GPS, historique, monitoring SMS, UI visuelle). Les elements 9--12 traitent de la qualite et de la robustesse (tests terrain, documentation, cache offline, gestion timeouts/retry).

% =============================================================================
\subsection{Raffinement des cas d'utilisation}"""
content = content.replace(old2, new2)
print("MOD 2: Backlog OK")

# ======================= MOD 3: Section Raffinement =======================
old3 = r"""La pr\'esente section d\'etaille le raffinement des cas d'utilisation principaux, incluant le diagramme de cas d'utilisation et le tableau des acteurs."""
new3 = r"""La pr\'esente section d\'etaille le raffinement des cas d'utilisation selon une approche de \textbf{d\'ecomposition hi\'erarchique}. Le syst\`eme est d\'ecrit \`a travers un \textbf{diagramme global} (vue d'ensemble) puis cinq \textbf{diagrammes d\'etaill\'es} par module fonctionnel (Diagnostic, Configuration, Mise \`a jour, Position GPS, Statistiques). Chaque diagramme d\'etaill\'e pr\'esente les commandes SMS exactes utilis\'ees dans le code source du projet."""
content = content.replace(old3, new3)
print("MOD 3: Raffinement OK")

# ======================= MOD 4: Explication acteurs =======================
old4 = r"""\caption{Tableau des acteurs principaux du syst\`eme GPS Field Assist}
\label{tab:actors}
\end{table}

\subsubsection{Diagramme de s\'equence - Diagnostic s\'equentiel ET8}"""
new4 = r"""\caption{Tableau des acteurs principaux du syst\`eme GPS Field Assist}
\label{tab:actors}
\end{table}

\textbf{Explication du tableau des acteurs :} Ce tableau definit les 5 acteurs qui interagissent avec le syst\`eme GPS Field Assist. Le \textbf{Technicien Terrain} est l'utilisateur principal qui pilote l'application mobile Flutter. Le \textbf{Backend API} (Node.js + PostgreSQL) sert de passerelle avec la plateforme Odoo. L'\textbf{Op\'erateur Mobile} fournit l'infrastructure GSM pour la transmission des SMS. Le \textbf{Syst\`eme SMS} repr\'esente l'API Telephony de l'appareil mobile. Les \textbf{Bo\^itiers GPS} sont les \'equipements terrain qui ex\'ecutent les commandes SMS.

\subsubsection{Diagramme de s\'equence - Diagnostic s\'equentiel multi-modules}"""
content = content.replace(old4, new4)
print("MOD 4: Acteurs OK")

# ======================= MOD 5: Deroulement sequence =======================
old5 = r"""Le diagnostic s\'equentiel suit une machine d'\'etat \`a 7 \'etapes principales. Chaque \'etape envoie une commande SMS au bo\^itier, attend la r\'eponse (timeout 60s, polling toutes les 3-4s), et valide ou corrige automatiquement en cas d'anomalie. Le syst\`eme inclut des m\'ecanismes de retry automatique (jusqu'\`a 3 tentatives) et des corrections passives (ex: resynchronisation horaire si l'horloge du bo\^itier est d\'esynchronis\'ee). Le cycle complet dure en moyenne 28 secondes."""
new5 = r"""Le diagnostic s\'equentiel s'adapte automatiquement \`a la famille de module d\'etect\'ee :

\begin{itemize}[leftmargin=*]
  \item \textbf{EasyTrace X} (ET6/ET8/ETX) : workflow 12 \'etapes possibles (7 principales + 5 corrections conditionnelles) avec timeout 60s. S\'equence : \texttt{*11*4\#} (IMEI) $\rightarrow$ \texttt{STATUS\#} (\'etat) $\rightarrow$ \texttt{UTC\#}
