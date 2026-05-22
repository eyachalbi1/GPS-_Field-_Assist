#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour modifier sprint1_report_improved.tex :
1. Ajouter colonnes ID et Points au backlog
2. Ajouter section commandes diagnostic par module
3. Ajouter section commandes configuration par module
4. Integrer les diagrammes detailles
"""

with open('sprint1_report_improved.tex', 'r', encoding='utf-8') as f:
    lines = f.readlines()

def find_line(substring):
    for i, line in enumerate(lines):
        if substring in line:
            return i
    return -1

# ============================================================================
# MOD 1: Ajouter colonnes ID et Points au tableau Backlog
# ============================================================================

# Trouver la ligne du tableau backlog
backlog_start = find_line('Backlog du Sprint')
if backlog_start >= 0:
    # Chercher la ligne \begin{tabularx} après backlog_start
    for i in range(backlog_start, min(backlog_start + 10, len(lines))):
        if 'begin{tabularx}' in lines[i] and 'c|' in lines[i]:
            # Remplacer la définition des colonnes
            old_cols = lines[i]
            new_cols = old_cols.replace(
                '{|>{\\columncolor{gray!10}}c|>{\\raggedright\\arraybackslash}X|c|}',
                '{|>{\\columncolor{gray!10}}c|>{\\raggedright\\arraybackslash}X|c|c|c|}'
            )
            lines[i] = new_cols
            print(f'MOD 1a: Colonnes tableau modifiees ligne {i}')
            break

    # Chercher la ligne d'en-tête du tableau
    for i in range(backlog_start, min(backlog_start + 15, len(lines))):
        if 'textbf{\\#}' in lines[i] and 'Element du Backlog' in lines[i+1]:
            # Remplacer l'en-tête
            old_header = lines[i] + lines[i+1]
            lines[i] = '\\textbf{ID} & \\textbf{Element du Backlog} & \\textbf{Points} & \\textbf{Statut} \\\\\n'
            # Supprimer la ligne suivante qui est l'ancien en-tête
            if 'Element du Backlog' in lines[i+1]:
                lines[i+1] = ''
            print(f'MOD 1b: En-tête tableau modifie ligne {i}')
            break

    # Modifier chaque ligne de données du tableau pour ajouter ID et Points
    # Les éléments 1-12 du backlog
    backlog_items = [
        ('1', 'Service SMS templates (commandes prédéfinies multi-modèles)', '5'),
        ('2', 'Écran diagnostic workflow (5 onglets, cartes colorées, retry automatique)', '8'),
        ('3', 'Écran EasyTrace ET8 (workflow séquentiel, timeout configurable)', '8'),
        ('4', 'Configuration APN par opérateur (Ooredoo/Orange/Telecom)', '3'),
        ('5', 'GPS prédictif offline (basé sur historique SMS)', '5'),
        ('6', 'Historique local (stockage persistant par module)', '3'),
        ('7', 'Monitoring SMS realtime (polling périodique, parsing automatique)', '3'),
        ('8', 'Interface résultats visuels (badges, barres, alertes)', '3'),
        ('9', 'Tests terrain sur 5 modèles de boîtiers', '5'),
        ('10', 'Documentation des commandes SMS', '3'),
        ('11', 'Cache offline (fonctionnement sans réseau)', '3'),
        ('12', 'Gestion timeouts et retry automatique', '3'),
    ]

    for item_id, desc, pts in backlog_items:
        for i in range(backlog_start, min(backlog_start + 50, len(lines))):
            if item_id + ' &' in lines[i] and desc[:20] in lines[i]:
                # Modifier la ligne pour ajouter les colonnes
                old_line = lines[i]
                # Remplacer "1 & Description &" par "BL-01 & Description & 5 &"
                new_line = old_line.replace(
                    f'{item_id} & ',
                    f'BL-{item_id.zfill(2)} & '
                )
                # Ajouter les points avant le statut
                # Chercher le pattern "& Termine" ou similaire
                if 'Termine' in new_line or 'Termin' in new_line:
                    # Inserer la colonne points avant le statut
                    parts = new_line.rsplit('&', 1)
                    if len(parts) == 2:
                        new_line = parts[0] + f'& {pts} &' + parts[1]
                lines[i] = new_line
                print(f'MOD 1c: Ligne backlog {item_id} modifiee')
                break

# ============================================================================
# MOD 2: Ajouter section Commandes de Diagnostic par Module
# ============================================================================

# Trouver la ligne après le diagramme de sequence
seq_end = find_line('Le cycle complet dure en moyenne 28 secondes.')
if seq_end >= 0:
    insert_pos = seq_end + 1

    diag_section = r'''
% =============================================================================
\subsubsection{Catalogue des commandes de diagnostic par module}
% =============================================================================

Cette section presente l\'ensemble des \textbf{commandes SMS exactes} utilisees pour le diagnostic de chaque famille de modules GPS, extraites du code source du projet (fichiers \texttt{easytrace\_diagnostic\_screen.dart}, \texttt{easytrace\_vii\_diag\_screen.dart} et \texttt{diagnostic\_screen.dart}).

\paragraph{EasyTrace X (ET8) --- Workflow sequentiel 7 etapes}

Le fichier \texttt{easytrace\_diagnostic\_screen.dart} implemente le diagnostic sequentiel pour les boitiers EasyTrace X avec les commandes exactes suivantes :

\begin{itemize}[leftmargin=*]
  \item \texttt{*11*4\#} --- Verification IMEI / IP / Online. Reponse attendue : \texttt{imei=XXXXXXXXXXXXXXX}
  \item \texttt{*77*6*IMEI\#} --- Restauration IMEI (commande conditionnelle, visible si IMEI incorrect)
  \item \texttt{STATUS\#} --- Contact / Fuel / Alimentation. Reponse : \texttt{STATUS,0}, \texttt{STATUS,1} ou \texttt{STATUS,2}
  \item \texttt{RESET\#} --- Redemarrage module (commande conditionnelle si STATUS contient \texttt{failed})
  \item \texttt{UTC\#} --- Heure UTC. Reponse : \texttt{utc,AAAAMMJJhhmmss}
  \item \texttt{UTC,0\#} --- Correction horloge (commande conditionnelle si decalage detecte)
  \item \texttt{GPRSSET\#} --- Protocole GPRS. Verification : \texttt{PROTOCOL:3,1}
  \item \texttt{PROTOCOL,3,1\#} --- Correction protocole (commande conditionnelle)
  \item \texttt{HC\#} --- Heartbeat config. Verification : \texttt{HC:60,7200,7200}
  \item \texttt{HC,60,7200,7200\#} --- Correction heartbeat (commande conditionnelle)
  \item \texttt{CORNER\#} --- Angle virage. Verification : \texttt{CORNER:20}
  \item \texttt{CORNER,20\#} --- Correction angle (commande conditionnelle)
  \item \texttt{CLR,BLIND\#} --- Vider historique (commande manuelle)
\end{itemize}

\textbf{Parametres techniques :} Timeout 60s par etape, retry automatique x3, polling inbox toutes les 3s, machine a etats avec branches conditionnelles.

\paragraph{EasyTrace VII (ET7) --- Workflow codes Z}

Le fichier \texttt{easytrace\_vii\_diag\_screen.dart} implemente le diagnostic pour les boitiers EasyTrace VII avec un protocole completement different base sur les codes Z :

\begin{itemize}[leftmargin=*]
  \item \texttt{\&\&tunavpsw,Z13,?} --- Lecture du mot de passe. Reponse : \texttt{Z13,...}
  \item \texttt{\&\&IMEI,pass,Z39,?,?,?,?} --- Lecture IP et Port. Fix : \texttt{\&\&IMEI,pass,Z39,1,41.226.24.13,1200,1}
  \item \texttt{\&\&IMEI,pass,Z31,?,?,?,?,?,?,?,?} --- Time Report. Fix : \texttt{\&\&IMEI,pass,Z31,60,600,60,600,60,600,5,1}
  \item \texttt{\&\&IMEI,pass,Z36,?,?,?,?} --- Distance Report. Fix : \texttt{\&\&IMEI,pass,Z36,0.7,3,3,1}
  \item \texttt{\&\&IMEI,pass,Z37,?,?,?} --- Angle Report. Fix : \texttt{\&\&IMEI,pass,Z37,25,2,1}
  \item \texttt{\&\&IMEI,pass,Z80,?,?} --- Contact ON/OFF. Fix : \texttt{\&\&IMEI,pass,Z80,1,0}
  \item \texttt{\&\&IMEI,pass,Z27,?,?} --- Lock GPS ACC off. Fix : \texttt{\&\&IMEI,pass,Z27,1.0,0}
\end{itemize}

\textbf{Commandes de reset (retry automatique) :}
\begin{itemize}[leftmargin=*]
  \item \texttt{\&\&IMEI,pass,Y35} --- Reset GPS (2 tentatives max)
  \item \texttt{\&\&IMEI,pass,Y36} --- Reset boitier (1 tentative)
  \item \texttt{\&\&IMEI,pass,Y09} --- Reset GSM
  \item \texttt{\&\&IMEI,pass,Y02} --- Wake Up
\end{itemize}

\textbf{Parametres techniques :} Timeout 50 minutes par etape, retry avec escalation (GPS $\rightarrow$ boitier $\rightarrow$ GSM), polling inbox toutes les 3s.

\paragraph{GV300CAN / EasyCanTrace --- Commandes manuelles AT+GTRTO}

Le fichier \texttt{diagnostic\_screen.dart} et \texttt{easytrace\_diagnostic\_screen.dart} implementent un panneau de commandes manuelles pour les boitiers GV300CAN avec les commandes AT exactes suivantes :

\begin{itemize}[leftmargin=*]
  \item \texttt{AT+GTRTO=gv300can,9,,3,,,,FFFF\$} --- Niveau batterie + etat chargeur
  \item \texttt{AT+GTRTO=gv300can,3,,,,,,FFFF\$} --- Redemarrer le terminal
  \item \texttt{AT+GTRTO=gv300can,5,,,,,,FFFF\$} --- Eteindre (power off)
  \item \texttt{AT+GTRTO=gv300can,2,,,,,,FFFF\$} --- Version firmware
\end{itemize}

\textbf{Commande de mise a jour firmware (onglet Update) :}
\begin{itemize}[leftmargin=*]
  \item \texttt{AT+GTUPD=gv300can,0,0,20,0,,,http://41.226.24.13:5000/api/download/GV300CANR00\_0B08\_to\_0C10.bin,,0,,,0001\$}
\end{itemize}

\textbf{Parametres techniques :} Timeout 60s par commande, polling inbox toutes les 3s, pas de workflow sequentiel (commandes manuelles individuelles).

'''

    lines.insert(insert_pos, diag_section + '\n')
    print(f'MOD 2: Section diagnostic par module inseree ligne {insert_pos}')

# ============================================================================
# MOD 3: Ajouter section Commandes de Configuration par Module
# ============================================================================

# Trouver la section Conception pour inserer apres le workflow
conception = find_line('Conception')
if conception >= 0:
    # Chercher la fin de la sous-section workflow
    for i in range(conception, min(conception + 100, len(lines))):
        if 'Le cycle complet dure en moyenne 28 secondes' in lines[i]:
            insert_pos = i + 1
            break
    else:
        insert_pos = conception + 5
else:
    insert_pos = len(lines) // 2

config_section = r'''
% =============================================================================
\subsection{Configuration des parametres reseau par module}
% =============================================================================

Cette section presente les \textbf{commandes SMS exactes} utilisees pour la configuration des parametres reseau (APN) selon l\'operateur mobile, extraites du fichier \texttt{config.dart}.

\subsubsection{Commandes APN exactes par operateur}

\begin{table}[H]
\centering
\small
\begin{tabularx}{\textwidth}{|c|X|c|c|}
\hline
\rowcolor{gray!15}
\textbf{Operateur} & \textbf{Commande SMS exacte} & \textbf{APN} & \textbf{Auth} \\ \hline
Telecom Tunisie & \texttt{APN,internet.tn\#} & internet.tn & Aucune \\ \hline
Orange Tunisie & \texttt{APN,apn.tunav.tn\#} & apn.tunav.tn & Aucune \\ \hline
Ooredoo Tunisie & \texttt{APN,m2m.tunav.com,tunav,tunav\#} & m2m.tunav.com & tunav / tunav \\ \hline
\end{tabularx}
\caption{Commandes APN exactes par operateur tunisien}
\label{tab:apn-commands}
\end{table}

\textbf{Explication du tableau des commandes APN :}

Ce tableau presente les 3 commandes SMS exactes implementees dans le fichier \texttt{config.dart} (classe Config, Map \texttt{apnCommands}). Chaque commande est associee a un operateur mobile tunisien : \textbf{Telecom Tunisie} utilise l\'APN public \texttt{internet.tn} sans authentification ; \textbf{Orange Tunisie} utilise l\'APN \texttt{apn.tunav.tn} sans authentification ; \textbf{Ooredoo Tunisie} utilise l\'APN \texttt{m2m.tunav.com} avec authentification obligatoire (utilisateur \texttt{tunav}, mot de passe \texttt{tunav}).

\subsubsection{Validation et retry automatique}

Apres l\'envoi d\'une commande APN, le systeme valide la configuration via la commande \texttt{GPRSSET\#} et attend la reponse \texttt{gprsset,APN\_OK}. En cas d\'echec, le mecanisme de retry automatique effectue les tentatives suivantes dans l\'ordre :

\begin{enumerate}[leftmargin=*]
  \item Telecom Tunisie (\texttt{APN,internet.tn\#})
  \item Orange Tunisie (\texttt{APN,apn.tunav.tn\#})
  \item Ooredoo Tunisie (\texttt{APN,m2m.tunav.com,tunav,tunav\#})
\end{enumerate}

\textbf{Parametres techniques :} Timeout 30s par APN, retry maximum 3 tentatives, persistance via SharedPreferences, cache 24h.

\subsubsection{Diagramme detaille --- Configuration APN}

\begin{figure}[H]
\centering
\includegraphics[width=0.95\textwidth]{config_commandes_detail.png}
\caption{Diagramme de cas d\'utilisation detaille --- Configuration APN}
\label{fig:config-detail}
\end{figure}

'''

lines.insert(insert_pos, config_section + '\n')
print(f'MOD 3: Section configuration par module inseree ligne {insert_pos}')

# ============================================================================
# MOD 4: Ajouter references aux diagrammes detailles
# ============================================================================

# Ajouter apres le diagramme de sequence principal
seq_fig = find_line('fig:sequence-diagram')
if seq_fig >= 0:
    # Trouver la fin de la figure
    for i in range(seq_fig, min(seq_fig + 10, len(lines))):
        if 'end{figure}' in lines[i]:
            insert_pos = i + 1
            break
    else:
        insert_pos = seq_fig + 5

    diagrams_section = r'''
\subsubsection{Diagrammes detailles par module}

Les figures \ref{fig:d1-detail} a \ref{fig:fw-detail} presentent les diagrammes detailles pour chaque module fonctionnel, avec les commandes SMS exactes utilisees dans le code source du projet.

\begin{figure}[H]
\centering
\includegraphics[width=0.95\textwidth]{d1_sequence_detail.png}
\caption{Diagramme de sequence detaille --- Diagnostic EasyTrace ET8}
\label{fig:d1-detail}
\end{figure}

\textbf{Commandes exactes du diagramme D1 :}
\begin{itemize}[leftmargin=*]
  \item Etape 1 : \texttt{*11*4\#} $\rightarrow$ \texttt{imei=867530921654321}
  \item Etape 2 : \texttt{STATUS\#} $\rightarrow$ \texttt{STATUS,1}
  \item Etape 3 : \texttt{UTC\#} $\rightarrow$ \texttt{utc,20260428101458} (correction : \texttt{UTC,0\#})
  \item Etape 4 : \texttt{GPRSSET\#} $\rightarrow$ \texttt{gprsset,APN\_OK}
  \item Etape 5 : \texttt{HC,60,7200,7200\#} $\rightarrow$ \texttt{HC,OK}
  \item Etape 6 : \texttt{PROTOCOL,3,1\#} $\rightarrow$ \texttt{PROTOCOL,OK}
  \item Etape 7 : \texttt{CORNER,20\#} $\rightarrow$ \texttt{CORNER,OK}
\end{itemize}

\begin{figure}[H]
\centering
\includegraphics[width=0.95\textwidth]{gps_commandes_detail.png}
