# -*- coding: utf-8 -*-
import shutil

# Restaurer le backup
shutil.copy('sprint1_report_improved_backup.tex', 'sprint1_report_improved.tex')

with open('sprint1_report_improved.tex', 'r', encoding='utf-8') as f:
    content = f.read()

# ======================= MODIFICATION 1: Explication User Stories =======================
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

# ======================= MODIFICATION 2: Explication Backlog =======================
old2 = r"""\caption{Backlog Sprint 1 - 12/12 elements implementes (100\%)}
\label{tab:backlog}
\end{table}"""
new2 = r"""\caption{Backlog Sprint 1 - 12/12 elements implementes (100\%)}
\label{tab:backlog}
\end{table}

\textbf{Explication du tableau du Backlog :}

Ce tableau liste les 12 elements du backlog du Sprint 1, tous marques comme \textbf{termines} (100\% de realisation). Les elements 1--4 concernent les fonctionnalites core (SMS, diagnostic, configuration APN, mise a jour firmware). Les elements 5--8 couvrent les services transversaux (prediction GPS, historique, monitoring SMS, UI visuelle). Les elements 9--12 traitent de la qualite et de la robustesse (tests terrain, documentation, cache offline, gestion timeouts/retry)."""
content = content.replace(old2, new2)

# ======================= MODIFICATION 3: Section Raffinement =======================
old3 = r"""% =============================================================================
\subsection{Raffinement des cas d'utilisation}
% =============================================================================

La presente section detaille le raffinement des cas d'utilisation principaux, incluant le diagramme de cas d'utilisation et le tableau des acteurs.

\subsubsection{Diagramme de cas d'utilisation - GPS Field Assist}

La figure \ref{fig:usecase-global} presente le diagramme de cas d'utilisation global du systeme \textbf{GPS Field Assist} implemente lors du Sprint 1. Ce diagramme est defini dans le fichier \texttt{sprint1\_usecase\_diagram\_v2.puml} au format PlantUML.

\begin{figure}[H]
\centering
% Genere depuis sprint1_usecase_diagram_v2.puml
% Commande: plantuml -tpng sprint1_usecase_diagram_v2.puml -o ./
% Note: L'image doit etre dans le meme repertoire que le .tex ou ajuster le chemin
\includegraphics[width=0.95\textwidth]{sprint1_usecase_diagram_v2.png}
\caption{Diagramme de cas d'utilisation - GPS Field Assist Sprint 1}
\label{fig:usecase-global}
\end{figure}

\textbf{Description du diagramme :}

Le diagramme identifie 5 acteurs principaux et leurs interactions avec le systeme. Il montre les relations d'inclusion et d'extension entre les differents cas d'utilisation. Le coeur du systeme est le diagnostic sequentiel, qui inclut obligatoirement l'envoi de SMS, le polling de la boite de reception, le parsing des reponses et le stockage dans l'historique. D'autres cas d'utilisation etendent ce workflow de base selon les besoins (recuperation IMEI, diagnostics alternatifs, retry APN, alertes predictives)."""

new3 = r"""% =============================================================================
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

content = content.replace(old3, new3)

# ======================= MODIFICATION 4: Explication tableau acteurs =======================
old4 = r"""\caption{Tableau des acteurs principaux du systeme GPS Field Assist}
\label{tab:actors}
\end{table}

\subsubsection{Diagramme de sequence - Diagnostic sequentiel ET8}"""

new4 = r"""\caption{Tableau des acteurs principaux du systeme GPS Field Assist}
\label{tab:actors}
\end{table}

\textbf{Explication du tableau des acteurs :} Ce tableau definit les 5 acteurs qui interagissent avec le systeme GPS Field Assist. Le \textbf{Technicien Terrain} est l'utilisateur principal qui pilote l'application mobile Flutter. Le \textbf{Backend API} (Node.js + PostgreSQL) sert de passerelle avec la plateforme Odoo. L'\textbf{Operateur Mobile} fournit l'infrastructure GSM pour la transmission des SMS. Le \textbf{Systeme SMS} represente l'API Telephony de l'appareil mobile. Les \textbf{Boitiers GPS} sont les equipements terrain qui executent les commandes SMS.

\subsubsection{Diagramme de sequence - Diagnostic sequentiel multi-modules}"""

content = content.replace(old4, new4)

# ======================= MODIFICATION 5: Deroulement du processus sequence =======================
old5 = r"""\textbf{Deroulement du processus :}

Le diagnostic sequentiel suit une machine d'etat a 7 etapes principales. Chaque etape envoie une commande SMS au boitier, attend la reponse (timeout 60s, polling toutes les 3-4s), et valide ou corrige automatiquement en cas d'anomalie. Le systeme inclut des mecanismes de retry automatique (jusqu'a 3 tentatives) et des corrections passives (ex: resynchronisation horaire si l'horloge du boitier est desynchronisee). Le cycle complet dure en moyenne 28 secondes."""

new5 = r"""\textbf{Deroulement du processus :}

Le diagnostic sequentiel s'adapte automatiquement a la famille de module detectee :

\begin{itemize}[leftmargin=*]
  \item \textbf{EasyTrace X} (ET6/ET8/ETX) : workflow 12 etapes possibles (7 principales + 5 corrections conditionnelles) avec timeout 60s. Sequence : \texttt{*11*4\#} (IMEI) $\rightarrow$ \texttt{STATUS\#} (etat) $\rightarrow$ \texttt{UTC\#} (horloge, corrige si besoin avec \texttt{UTC,0\#}) $\rightarrow$ \texttt{GPRSSET\#} (reseau, corrige PROTOCOL si besoin) $\rightarrow$ \texttt{HC\#} (heartbeat, corrige avec \texttt{HC,60,7200,7200\#}) $\rightarrow$ \texttt{CORNER\#} (angle, corrige avec \texttt{CORNER,20\#}). Commandes utilitaires : \texttt{RESET\#} (redemarrage), \texttt{CLR,BLIND\#} (vider historique). Retry x3 par etape. Code source : \texttt{easytrace\_diagnostic\_screen.dart}.
  \item \textbf{EasyTrace VII} (ET7) : protocole Z avec timeout 50min. Sequence : \texttt{\&\&tunavpsw,Z13,?} (password) $\rightarrow$ \texttt{\&\&IMEI,pass,Z39,?,?,?,?} (IP/Port) $\rightarrow$ \texttt{\&\&IMEI,pass,Z31,?,?,?,?,?,?,?,?} (Time Report) $\rightarrow$ \texttt{\&\&IMEI,pass,Z36,?,?,?,?} (Distance) $\rightarrow$ \texttt{\&\&IMEI,pass,Z37,?,?,?} (Angle) $\rightarrow$ \texttt{\&\&IMEI,pass,Z80,?,?} (Contact) $\rightarrow$ \texttt{\&\&IMEI,pass,Z27,?,?} (Lock GPS). En cas d'echec : resets progressifs \texttt{Y35} (GPS, 15s) $\rightarrow$ \texttt{Y36} (boitier, 20s) $\rightarrow$ \texttt{Y09} (GSM, 10s) + \texttt{Y02} (wake up, 15s). Commandes fix : \texttt{Z39,1,41.226.24.13,1200,1}, \texttt{Z31,60,600,60,600,60,600,5,1}, \texttt{Z36,0.7,3,3,1}, \texttt{Z37,25,2,1}, \texttt{Z80,1,0}, \texttt{Z27,1.0,0}. Code source : \texttt{easytrace\_vii\_diag\_screen.dart}.
  \item \textbf{GV300CAN/EasyCanTrace} : pas de workflow sequentiel --- panneau manuel de commandes \texttt{AT+GTRTO}. Commandes : \texttt{AT+GTRTO=gv300can,9,,3,,,,FFFF\$} (batterie), \texttt{AT+GTRTO=gv300can,3,,,,,,FFFF\$} (redemarrage), \texttt{AT+GTRTO=gv300can,5,,,,,,FFFF\$} (power-off), \texttt{AT+GTRTO=gv300can,2,,,,,,FFFF\$} (version firmware). Commande mise a jour OTA : \texttt{AT+GTUPD=gv300can,0,0,20,0,,,http://41.226.24.13:5000/api/download/GV300CANR00\_0B08\_to\_0C10.bin,,0,,,0001\$}. Code source : \texttt{diagnostic\_screen.dart}.
\end{itemize}

Le polling de la boite SMS se fait toutes les 3--4 secondes. Le parsing utilise des regex adaptees a chaque modele. Le cycle complet dure en moyenne 28 secondes pour EasyTrace X."""

content = content.replace(old5, new5)

# ======================= MODIFICATION 6: Explication architecture =======================
old6 = r"""\caption{Architecture globale du systeme - Sprint 1}
\label{fig:architecture-global}
\end{figure}

\textbf{Composants principaux :}"""

new6 = r"""\caption{Architecture globale du systeme - Sprint 1}
\label{fig:architecture-global}
\end{figure}

\textbf{Explication du schema d'architecture :}

Ce schema en couches illustre l'architecture client-serveur du systeme GPS Field Assist. La \textbf{couche Frontend} (Flutter) contient 4 composants : l'Interface UI regroupe les 5 onglets (Diagnostic, Configuration, Carte, Statistiques), le Service SMS gere l'envoi/reception via l'API Telephony, le GPS Prediction Service analyse l'historique pour les alertes, et le Cache Offline persiste les donnees via SharedPreferences. La \textbf{couche Backend} (Node.js + PostgreSQL) expose une API REST synchronisee avec Odoo et stocke les donnees dans PostgreSQL. La \textbf{couche Externe} inclut la passerelle SMS de l'operateur GSM et les cartes OpenStreetMap.

\textbf{Composants principaux :}"""

content = content.replace(old6, new6)

# ======================= MODIFICATION 7: Explication workflow =======================
old7 = r"""\caption{Workflow sequentiel du diagnostic - Processus avec corrections automatiques}
\label{fig:workflow-diagnostic}
\end{figure}

\textbf{Fonctionnement :}

Le workflow est une machine d'etat sequentielle avec 7 etapes principales. Chaque etape comporte un timeout de 60 secondes et un mecanisme de retry automatique (jusqu'a 3 tentatives). Si une etape echoue, une action corrective est declenchee (recuperation de l'identifiant depuis le backend, correction automatique de l'horloge, ou retry avec des operateurs APN alternatifs). Le cycle complet dure en moyenne 28 secondes, respectant l'objectif de moins de 30 secondes."""

new7 = r"""\caption{Workflow sequentiel du diagnostic - Processus avec corrections automatiques}
\label{fig:workflow-diagnostic}
\end{figure}

\textbf{Explication du workflow sequentiel :}

Ce diagramme d'activite TikZ represente la machine d'etat du diagnostic automatise pour les boitiers EasyTrace X. Le processus debute par la \textbf{verification d'identite} (etape 1, commande \texttt{*11*4\#}) : si l'IMEI est incorrect, le systeme recupere depuis le backend puis restaure (\texttt{*77*6*IMEI\#}) avec retry x3. L'etape 2 (\textbf{controle d'etat}, \texttt{STATUS\#}) verifie le fonctionnement. L'etape 3 (\textbf{synchronisation horloge}, \texttt{UTC\#}) detecte les decalages et applique automatiquement \texttt{UTC,0\#} si necessaire. L'etape 4 (\textbf{configuration reseau}, \texttt{GPRSSET\#}) valide l'APN ; en cas d'echec, retry sur les 3 operateurs. L'etape 5 (\textbf{heartbeat}, \texttt{HC\#}) et l'etape 6 (\textbf{protocole/angle}) valident les parametres de communication. Chaque decision (losanges orange) represente un point de controle avec branchement conditionnel. Les fleches vertes indiquent le flux nominal, les fleches rouges les flux d'erreur, et les fleches pointillees les boucles de correction. Le cycle complet dure en moyenne 28 secondes, respectant l'objectif de moins de 30 secondes."""

content = content.replace(old7, new7)

# ======================= MODIFICATION 8: Explication tests =======================
old8 = r"""\caption{Criteres d'acceptation du Sprint 1}
\label{tab:criteria}
\end{table}

\subsection{Campagne de tests terrain}"""

new8 = r"""\caption{Criteres d'acceptation du Sprint 1}
\label{tab:criteria}
\end{table}

\textbf{Explication du tableau des criteres d'acceptation :}

Ce tableau compare les objectifs definis en debut de sprint avec les resultats reels obtenus lors de la campagne de tests terrain. Les 5 criteres sont tous \textbf{valides} (vert) : le taux de succes global des diagnostics atteint 95,2\% (objectif > 95\%), la precision GPS est de 92\% (objectif < 15m dans 92\% des cas), le temps moyen de cycle est de 28 secondes (objectif < 30s), le fonctionnement offline est garanti via SharedPreferences, et l'interface utilisateur fournit un feedback visuel immediat par codes couleur.

\subsection{Campagne de tests terrain}"""

content = content.replace(old8, new8)

# ======================= MODIFICATION 9: Explication tests par modele =======================
old9 = r"""\caption{Resultats des tests par modele de boitier}
\label{tab:test-results}
\end{table}

\subsection{Tests par module fonctionnel}"""

new9 = r"""\caption{Resultats des tests par modele de boitier}
\label{tab:test-results}
\end{table}

\textbf{Explication du tableau des resultats par modele :}

Ce tableau presente les resultats de la campagne de tests terrain (62 sequences) pour chacun des 5 modeles de boitiers supportes. Pour chaque modele, les \textbf{commandes exactes testees} sont specifiees : ET8 utilise le workflow sequentiel complet 7 etapes (\texttt{*11*4\#} $\rightarrow$ \texttt{STATUS\#} $\rightarrow$ \texttt{UTC\#} $\rightarrow$ \texttt{GPRSSET\#} $\rightarrow$ \texttt{HC\#} $\rightarrow$ \texttt{CORNER\#}), GV300CAN teste les commandes firmware (\texttt{AT+GTUPD}) et AT+GTRTO, FM4200 teste le diagnostic standard et la configuration APN, GT06N teste les commandes de localisation (\texttt{*11*3\#} et \texttt{\&\&IMEI,Y01}), MT02S teste les commandes heartbeat et le diagnostic sequentiel. Le taux de succes global est de 95,2\%, la precision GPS moyenne est de 92\% (< 15m), et le temps moyen de cycle est de 28 secondes.

\subsection{Tests par module fonctionnel}"""

content = content.replace(old9, new9)

# ======================= SAUVEGARDE =======================
with open('sprint1_report_improved.tex', 'w', encoding='utf-8') as f:
    f.write(content)

print("Toutes les modifications ont ete appliquees avec succes !")
print("Fichier final : sprint1_report_improved.tex")
