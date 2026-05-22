# -*- coding: utf-8 -*-
with open('sprint1_report_improved.tex', 'r', encoding='utf-8') as f:
    content = f.read()

def insert_after(marker, text_to_insert):
    """Insère du texte après un marqueur unique"""
    pos = content.find(marker)
    if pos == -1:
        print(f"MARQUEUR NON TROUVE: {marker[:50]}...")
        return False
    end_pos = pos + len(marker)
    global content
    content = content[:end_pos] + text_to_insert + content[end_pos:]
    print(f"INSERTION OK: {marker[:40]}...")
    return True

def replace_between(start_marker, end_marker, new_text):
    """Remplace le texte entre deux marqueurs"""
    start_pos = content.find(start_marker)
    if start_pos == -1:
        print(f"START NON TROUVE: {start_marker[:50]}...")
        return False
    end_pos = content.find(end_marker, start_pos + len(start_marker))
    if end_pos == -1:
        print(f"END NON TROUVE: {end_marker[:50]}...")
        return False
    global content
    content = content[:start_pos] + new_text + content[end_pos + len(end_marker):]
    print(f"REMPLACEMENT OK: {start_marker[:40]}... -> {end_marker[:40]}...")
    return True

# ========== MOD 1: Explication Backlog ==========
insert_after(
    r"\label{tab:backlog}" + "\n" + r"\end{table}",
    "\n\n" + r"\textbf{Explication du tableau du Backlog :}" + "\n\nCe tableau liste les 12 elements du backlog du Sprint 1, tous marques comme termines (100 pour cent de realisation). Les elements 1--4 concernent les fonctionnalites core (SMS, diagnostic, configuration APN, mise a jour firmware). Les elements 5--8 couvrent les services transversaux (prediction GPS, historique, monitoring SMS, UI visuelle). Les elements 9--12 traitent de la qualite et de la robustesse (tests terrain, documentation, cache offline, gestion timeouts/retry)."
)

# ========== MOD 2: Raffinement + diagramme global ==========
replace_between(
    r"% =============================================================================" + "\n" + r"\subsection{Raffinement des cas d'utilisation}" + "\n" + r"% =============================================================================" + "\n\n",
    r"\subsubsection{Diagramme de cas d'utilisation - GPS Field Assist}" + "\n\n",
    r"% =============================================================================" + "\n" + r"\subsection{Raffinement des cas d'utilisation}" + "\n" + r"% =============================================================================" + "\n\n" +
    r"La presente section detaille le raffinement des cas d'utilisation selon une approche de decomposition hierarchique. Le systeme est decrit a travers un diagramme global (vue d'ensemble) puis cinq diagrammes detailles par module fonctionnel (Diagnostic, Configuration, Mise a jour, Position GPS, Statistiques). Chaque diagramme detaille presente les commandes SMS exactes utilisees dans le code source du projet." + "\n\n" +
    r"\subsubsection{Diagramme de cas d'utilisation global --- GPS Field Assist}" + "\n\n"
)

# ========== MOD 3: Description diagramme global ==========
replace_between(
    r"\textbf{Description du diagramme :}" + "\n\n",
    r"\subsubsection{Tableau des acteurs principaux}",
    r"\textbf{Explication du diagramme global :} Ce diagramme identifie 5 acteurs principaux (Technicien, Boitier GPS, Operateur Mobile, Backend API, Systeme SMS) et 5 modules fonctionnels regroupes en packages : Diagnostic, Configuration APN, Mise a jour Firmware, Position GPS et Statistiques. Les relations <<include>> indiquent les dependances obligatoires et les <<extend>> representent les extensions conditionnelles (retry APN si echec, correction automatique si anomalie)." + "\n\n" +
    r"\subsubsection{Tableau des acteurs principaux}"
)

# ========== MOD 4: Explication acteurs + titre sequence ==========
replace_between(
    r"\label{tab:actors}" + "\n" + r"\end{table}" + "\n\n",
    r"\subsubsection{Diagramme de s",
    r"\label{tab:actors}" + "\n" + r"\end{table}" + "\n\n" +
    r"\textbf{Explication du tableau des acteurs :} Ce tableau definit les 5 acteurs qui interagissent avec le systeme GPS Field Assist. Le \textbf{Technicien Terrain} est l'utilisateur principal qui pilote l'application mobile Flutter. Le \textbf{Backend API} (Node.js + PostgreSQL) sert de passerelle avec la plateforme Odoo. L'\textbf{Operateur Mobile} fournit l'infrastructure GSM pour la transmission des SMS. Le \textbf{Systeme SMS} represente l'API Telephony de l'appareil mobile. Les \textbf{Boitiers GPS} sont les equipements terrain qui executent les commandes SMS." + "\n\n" +
    r"\subsubsection{Diagramme de s"
)

# ========== MOD 5: Titre sequence ET8 -> multi-modules ==========
replace_between(
    r"\subsubsection{Diagramme de sequence - Diagnostic sequentiel ET8}" + "\n\n",
    r"La figure \ref{fig:sequence-diagram} presente le diagramme de sequence detaille du processus de diagnostic sequentiel pour le modele EasyTrace ET8.",
    r"\subsubsection{Diagramme de sequence - Diagnostic sequentiel multi-modules}" + "\n\n" +
    r"La figure \ref{fig:sequence-diagram} presente le diagramme de sequence detaille du processus de diagnostic sequentiel pour les differentes familles de modules (EasyTrace X, EasyTrace VII, GV300CAN)."
)

# ========== MOD 6: Deroulement du processus ==========
replace_between(
    r"\textbf{Deroulement du processus :}" + "\n\n",
    r"% =============================================================================" + "\n" + r"\newpage",
    r"\textbf{Deroulement du processus :}" + "\n\n" +
    r"Le diagnostic sequentiel s'adapte automatiquement a la famille de module detectee :" + "\n\n" +
    r"\begin{itemize}[leftmargin=*]" + "\n" +
    r"  \item \textbf{EasyTrace X} (ET6/ET8/ETX) : workflow 12 etapes possibles (7 principales + 5 corrections conditionnelles) avec timeout 60s. Sequence : \texttt{*11*4\#} (IMEI) $\rightarrow$ \texttt{STATUS\#} (etat) $\rightarrow$
