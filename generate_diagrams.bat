@echo off
REM ============================================================================
REM Script de génération des diagrammes PlantUML pour Sprint 1
REM ============================================================================

cd /d "%~dp0"

echo.
echo ========================================
echo Generation des diagrammes PlantUML
echo ============================================================================

REM Verifier Java
java -version >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Java non trouve. Installez Java JRE 8+.
    pause
    exit /b 1
)

REM Creer le repertoire de sortie
if not exist output mkdir output

echo.
echo [1/2] Generation du diagramme de cas d'utilisation...
java -jar "C:\Program Files\PlantUML\plantuml.jar" -tpng sprint1_usecase_diagram_v2.puml -o output\
if errorlevel 1 (
    echo [ERREUR] Echec generation usecase diagram
    pause
    exit /b 1
)
echo [OK] Diagramme de cas d'utilisation generer: output\sprint1_usecase_diagram_v2.png

echo.
echo [2/2] Generation du diagramme de sequence...
java -jar "C:\Program Files\PlantUML\plantuml.jar" sprint1_sequence_diagram_v2.puml -o output\
if errorlevel 1 (
    echo [ERREUR] Echec generation sequence diagram
    pause
    exit /b 1
)
echo [OK] Diagramme de sequence generer: output\sprint1_sequence_diagram_v2.png

echo.
echo ============================================================================
echo Tous les diagrammes ont ete generes avec succes!
echo ============================================================================
echo.
echo Pour compiler le rapport LaTeX :
echo   1. Assurez-vous que les images PNG sont dans output/
echo   2. Compilez sprint1_chapter.tex avec pdflatex ou xelatex
echo   3. Le document referencera automatiquement les images
echo.
pause
