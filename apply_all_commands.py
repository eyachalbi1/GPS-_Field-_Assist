#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour modifier sprint1_report_improved.tex:
1. Ajouter colonnes ID et Points au backlog
2. Ajouter toutes les commandes de diagnostic par module
3. Ajouter toutes les commandes de configuration par module + opérateurs
4. Ajouter les diagrammes détaillés
"""

import re

def read_file():
    with open('sprint1_report_improved.tex', 'r', encoding='utf-8') as f:
        return f.read()

def write_file(content):
    with open('sprint1_report_improved.tex', 'w', encoding='utf-8') as f:
        f.write(content)

def replace_section(content, start_marker, end_marker, new_section):
    """Remplace une section entre deux marqueurs."""
    pattern = re.escape(start_marker) + '.*?' + re.escape(end_marker)
    match = re.search(pattern, content, re.DOTALL)
    if match:
        old_section = match.group(0)
        # Trouver le début exact
        start_idx = content.find(start_marker)
        end_idx = content.find(end_marker, start_idx) + len(end_marker)
        return content[:start_idx] + new_section + content[end_idx:]
    return content

def main():
    content = read_file()
    
    # =========================================================================
    # 1. MODIFIER LE BACKLOG - Ajouter colonnes ID et Points
    # =========================================================================
    old_backlog_table = r"""\begin{table}[H]
\centering
\small
\begin{tabularx}{\textwidth}{|>{\columncolor{gray!10}}c|>{\raggedright\arraybackslash}X|c|}
\hline
\textbf{\#} & \textbf{Élément du Backlog} & \textbf{Statut} \\{
\hline
1 & Service SMS templates"""
    
    new_backlog_table = r"""\begin{table}[H]
\centering
\small
\begin{tabularx}{\textwidth}{|>{\columncolor{gray!10}}c|c|>{\raggedright\arraybackslash}X|c|c|}
\hline
\textbf{\#} & \textbf{ID} & \textbf{Élément du Backlog} & \textbf{Points} & \textbf{Statut} \\{
\hline
1 & US-01 & Service SMS templates"""
    
    content = content.replace(old_backlog_table, new_backlog_table)
    
    # Modifier les lignes du backlog pour ajouter ID et Points
    backlog_items = [
        ("1 & Service SMS templates", "1 & US-01 & Service SMS templates", "5"),
        ("2 & Écran diagnostic workflow", "2 & US-05 & Écran diagnostic workflow", "8"),
        ("3 & Écran EasyTrace ET8", "3 & US-05 & Écran EasyTrace ET8", "8"),
        ("4 & Configuration APN par opérateur", "4 & US-02 & Configuration APN par opérateur", "3"),
        ("5 & GPS prédictif offline", "5 & US-04 & GPS prédictif offline", "5"),
        ("6 & Historique local", "6 & US-01 & Historique local", "5"),
        ("7 & Monitoring SMS realtime", "7 & US-01 & Monitoring SMS realtime", "5"),
        ("8 & Interface résultats visuels", "8 & US-06 & Interface résultats visuels", "3"),
        ("9 & Tests terrain sur 5 modèles", "9 & US-01 & Tests terrain sur 5 modèles", "5"),
        ("10 & Documentation des commandes SMS", "10 & US-01 & Documentation des commandes SMS", "5"),
        ("11 & Cache offline", "11 & US-02 & Cache offline", "3"),
        ("12 & Gestion timeouts et retry automatique", "12 & US-05 & Gestion timeouts et retry automatique", "8"),
    ]
    
    for old_line, new_line_prefix, points in backlog_items:
        if old_line in content:
            # Trouver la ligne complète
            idx = content.find(old_line)
            end_idx = content.find("\\hline", idx)
            old_full_line = content[idx:end_idx]
            # Remplacer
            new_full_line = new_line_prefix + old_full_line[len(old_line):]
            # Insérer les points avant le statut
            new_full_line = new_full_line.replace(
                "&\n\\cellcolor{successgreen!30}Terminé",
                f"& {points} &\n\\cellcolor{{successgreen!30}}Terminé"
            )
            content = content[:idx] + new_full_line + content[end_idx:]
    
    # Modifier la ligne Total des points
    old_total = r"\multicolumn{3}{|r|}{\textbf{Total des points}}"
    new_total = r"\multicolumn{4}{|r|}{\textbf{Total des points}}"
    content = content.replace(old_total, new_total)
    
    # =========================================================================
    # 2. AJOUTER SECTION COMMANDES DE DIAGNOSTIC PAR MODULE
    # =========================================================================
    
    # Trouver la section après le diagramme de séquence
    diag_section_marker = r"\subsubsection{Diagramme de sequence - Diagnostic sequentiel multi-modules}"
    diag_end_marker = r"% ============================================================================="
    
    new_diag_section = r"""\subsubsection{Diagramme de sequence - Diagnostic sequentiel multi-modules}

La figure \ref{fig:sequence-diagram} presente le diagramme de sequence detaille du processus de diagnostic sequentiel pour les differentes familles de modules (EasyTrace X, EasyTrace VII, GV300CAN).

\begin{figure}[H]
\centering
% Genere depuis sprint1_sequence_diagram_v2.puml
% Commande: plantuml sprint1_sequence_diagram_v2.puml -o output/
\includegraphics[width=0.95\textwidth]{output/sprint1_sequence_diagram_v2.png}
\caption{Diagramme de sequence - Diagnostic sequentiel EasyTrace ET8}
\label{fig:sequence-diagram}
\end{figure}

\textbf{Deroulement du processus :}

Le diagnostic sequentiel suit une machine d'etat a 7 etapes principales. Chaque etape envoie une commande SMS au boitier, attend la reponse (timeout 60s, polling toutes les 3-4s), et valide ou corrige automatiquement en cas d'anomalie. Le systeme inclut des mecanismes de retry automatique (jusqu'a 3 tentatives) et des corrections passives (ex: resynchronisation horaire si l'horloge du boitier est desynchronisee). Le cycle complet dure en moyenne 28 secondes.

\subsubsection{Commandes de Diagnostic par Module}

Cette section detaille les \textbf{commandes SMS exactes} utilisees pour le diagnostic de chaque famille de modules, telles qu'implementees dans le code source du projet.

\paragraph{EasyTrace X (ET8) - Commandes de Diagnostic}

Le fichier \texttt{easytrace\_diagnostic\_screen.dart} implemente le workflow sequentiel avec 12 commandes possibles (7 principales + 5 correctives conditionnelles) :

\begin{table}[H]
\centering
\small
\begin{tabularx}{\textwidth}{|c|X|X|c|}
\hline
\rowcolor{gray!15}
\textbf{Etape} & \textbf{Commande} & \textbf{Description} & \textbf{Type} \\
\hline
1 & \texttt{*11*4\#} & Verification IMEI / IP / Online & Principale \\
\hline
1b & \texttt{*77*6*IMEI\#} & Restauration IMEI depuis backend & Corrective \\
\hline
2 & \texttt{STATUS\#} & Contact / Fuel / Alimentation & Principale \\
\hline
2b & \texttt{RESET\#} & Redemarrage module si FAILED & Corrective \\
\hline
3 & \texttt{UTC\#} & Verification heure UTC & Principale \\
\hline
3b & \texttt{UTC,0\#} & Correction fuseau horaire UTC & Corrective \\
\hline
4 & \texttt{GPRSSET\#} & Protocol GPRS / Reseau & Principale \\
\hline
4b & \texttt{PROTOCOL,3,1\#} & Correction protocole (3=TCP, 1=SMS) & Corrective \\
\hline
5 & \texttt{HC\#} & Heartbeat config (interrogation) & Principale \\
\hline
5b & \texttt{HC,60,7200,7200\#} & Correction heartbeat (60s, 7200s, 7200s) & Corrective \\
\hline
6 & \texttt{CORNER\#} & Angle virage (interrogation) & Principale \\
\hline
6b & \texttt{CORNER,20\#} & Correction angle virage (20 degres) & Corrective \\
\hline
Utilitaire & \texttt{CLR,BLIND\#} & Vider historique local & Maintenance \\
\hline
\end{tabularx}
\caption{Commandes de diagnostic EasyTrace X (ET8)}
\label{tab:diag-et8}
\end{table}

\textbf{Logique du workflow :} Le systeme envoie d'abord \texttt{*11*4\#} pour obtenir l'IMEI. Si l'IMEI est invalide (000000000000000) ou inconnu, il recupere le SerialNumber depuis l'API backend et envoie \texttt{*77*6*IMEI\#} pour le restaurer. Chaque etape suivante verifie une foncionnalite : \texttt{STATUS\#} verifie l'etat, \texttt{UTC\#} verifie l'horloge (avec correction automatique \texttt{UTC,0\#} si decalage), \texttt{GPRSSET\#} verifie le reseau, \texttt{HC\#} et \texttt{CORNER\#} verifient les parametres de communication. En cas d'echec, les commandes correctives sont automatiquement injectees.

\paragraph{EasyTrace VII (ET7) - Commandes de Diagnostic}

Le fichier \texttt{easytrace\_vii\_diag\_screen.dart} implemente un workflow specifique avec 7 etapes de configuration Z et 4 commandes de reset :

\begin{table}[H]
\centering
\small
\begin{tabularx}{\textwidth}{|c|X|X|c|}
\hline
\rowcolor{gray!15}
\textbf{Etape} & \textbf{Commande requete} & \textbf{Commande correction} & \textbf{Description} \\
\hline
1 & \texttt{&&tunavpsw,Z13,?} & - & Lecture password \\
\hline
2 & \texttt{&&IMEI,pass,Z39,?,?,?,?} & \texttt{&&IMEI,pass,Z39,1,41.226.24.13,1200,1} & IP \& Port serveur \\
\hline
3 & \texttt{&&IMEI,pass,Z31,?,?,?,?,?,?,?,?} & \texttt{&&IMEI,pass,Z31,60,600,60,600,60,600,5,1} & Time Report \\
\hline
4 & \texttt{&&IMEI,pass,Z36,?,?,?,?} & \texttt{&&IMEI,pass,Z36,0.7,3,3,1} & Distance Report \\
\hline
5 & \texttt{&&IMEI,pass,Z37,?,?,?} & \texttt{&&IMEI,pass,Z37,25,2,1} & Angle Report \\
\hline
6 & \texttt{&&IMEI,pass,Z80,?,?} & \texttt{&&IMEI,pass,Z80,1,0} & Contact ON/OFF \\
\hline
7 & \texttt{&&IMEI,pass,Z27,?,?} & \texttt{&&IMEI,pass,Z27,1.0,0} & Lock GPS ACC off \\
\hline
\end{tabularx}
\caption{Commandes de diagnostic/configuration EasyTrace VII (ET7)}
\label{tab:diag-et7}
\end{table}

\textbf{Commandes de reset (en cas de timeout) :}
\begin{itemize}
\item \texttt{&&IMEI,pass,Y35} - Reset GPS (2 tentatives max, attente 15s)
\item \texttt{&&IMEI,pass,Y36} - Reset Boitier (1 tentative, attente 20s)
\item \texttt{&&IMEI,pass,Y09} - Reset GSM (1 tentative, attente 10s)
\item \texttt{&&IMEI,pass,Y02} - Wake Up (apres reset GSM, attente 15s)
\end{itemize}

\textbf{Timeout :} 50 minutes par etape (specifique ET7), retry avec reset automatique.

\paragraph{GV300CAN / EasyCanTrace - Commandes de Diagnostic}

Le fichier \texttt{easytrace\_diagnostic\_screen.dart} (mode GV300CAN) implemente un panneau de commandes manuelles AT+GTRTO :

\begin{table}[H]
\centering
\small
\begin{tabularx}{\textwidth}{|c|X|X|}
\hline
\rowcolor{gray!15}
\textbf{Commande} & \textbf{Description} & \textbf{Reponse attendue} \\
\hline
\texttt{AT+GTRTO=gv300can,9,,3,,,,FFFF\$} & Niveau batterie + etat chargeur & Donnees batterie \\
\hline
\texttt{AT+GTRTO=gv300can,3,,,,,,FFFF\$} & Redemarrer terminal & Confirmation reboot \\
\hline
\texttt{AT+GTRTO=gv300can,5,,,,,,FFFF\$} & Power off (eteindre) & Pas de reponse \\
\hline
\texttt{AT+GTRTO=gv300can,2,,,,,,FFFF\$} & Version firmware & Informations FW \\
\hline
\end{tabularx}
\caption{Commandes de diagnostic GV300CAN / EasyCanTrace}
\label{tab:diag-gv300}
\end{table}

\textbf{Note :} Contrairement aux EasyTrace X/VII, le GV300CAN n'utilise pas de workflow sequentiel automatise. Le technicien selectionne manuellement la commande souhaitee dans le panneau dedie. Le mode de position ouvre automatiquement la carte lorsque la reponse contient les coordonnees GPS.

% ============================================================================="""
    
    # Remplacer la section diagnostic
    content = replace_section(content, diag_section_marker, diag_end_marker, new_diag_section)
    
    # =========================================================================
    # 3. AJOUTER SECTION COMMANDES DE CONFIGURATION PAR MODULE
    # =========================================================================
    
    # Trouver la section Realisation - Module Diagnostic + Configuration
    config_section_marker = r"\subsection{Module Diagnostic + Configuration (Combiné)}"
    config_end_marker = r"\subsection{Module Mise à Jour Firmware (Isolé)}"
    
    new_config_section = r"""\subsection{Module Diagnostic + Configuration (Combiné)}

\begin{figure}[H]
\centering
\fbox{\parbox{0.76\textwidth}{\centering\vspace{2cm}\textbf{[Capture d'ecran : Module Diagnostic + Configuration]}\\{
\vspace{0.5cm}
\textit{diagnostic\_screen.dart - onglets Position/Update/Config/Diagnostic/STAT}\\{
Affiche : Workflow sequentiel 7 etapes (ET8), badges ✓⚠✗, barre progression,\\{
Configuration APN Ooredoo/Orange/Telecom en 1 clic, persistance locale.}\vspace{2cm}}}
\caption{Module Diagnostic et Configuration combines}
\label{fig:diagnostic_config_screen}
\end{figure}

\textbf{Fonctions affichees :}
\begin{itemize}[leftmargin=*]
  \item \textbf{Onglets multi-fonctions} : Position (carte GPS), Mise a jour (firmware), Configuration (APN), Diagnostic (workflow), STAT (statistiques parc)
  \i
