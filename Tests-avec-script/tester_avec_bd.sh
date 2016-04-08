#!/usr/bin/env bash

#####################################################################
# Script pour l'execution de tests d'acceptation sur un programme qui
# manipule une base de donnees textuelle, representee par un unique
# fichier texte: voir fonction usage pour les details.
#####################################################################


###################################################
# Fonctions pour debogage et traitement des erreurs.
###################################################

# Pour generer des traces de debogage avec la function debug, il
# suffit de supprimer le <<#>> au debut de la ligne suivante.
#DEBUG=1

function debug {
    [[ -z $DEBUG ]] && return

    echo -n "[debug] "
    for arg in "$@"
    do
        echo -n "'$arg' "
    done
    echo ""
}

function erreur {
    msg=$1

    echo "*** Erreur: $msg"
    echo ""

    exit 1
}

function erreur_nb_arguments {
    erreur  "Nombre incorrect d'arguments: $@"
    usage
}

###################################################
# Fonction usage.
###################################################

function usage {
    cat <<EOF
usage:
  $0 [--test=prefixe] [--bd=bd_a_utiliser] programme repertoire [wip]

  programme: le programme (un executable) qu'on veut tester, qui
             lit/ecrit une BD textuelle representee par un unique
             fichier

  repertoire: le repertoire contenant les jeux d'essais
     
  prefixe: la chaine qui identifie les fichiers qui sont des cas de tests
           si omis => prefixe = "test"

  bd_a_utiliser: nom du fichier qui represente la BD textuelle a manipuler
           si omis => bd_a_utiliser = ".bd.txt"

  wip: lorsqu'on veut executer seulement certains tests, on specifie
       une sous-chaine qui sera matchee avec les noms de test et seuls
       ceux qui matchent seront executes.


  Pour un cas de test "_foo" avec le prefixe par defaut qui matche wip si specifie:
   a) On doit avoir les deux fichiers suivants:
      test_foo.input:  les lignes a transmettre au programme
      test_foo.output: les lignes qui doivent etre produites par le programme

   b) On peut avoir le fichier suivant:
      test_foo.arguments: une (1) ligne contenant les valeurs a transmettre 
                         comme arguments au programme

   c) Si le programme modifie la BD textuelle, on peut aussi avoir les deux 
      fichiers suivants:
      test_foo.bd-avant: contenu de la BD avant le test (etat initial)
      test_foo.bd-apres: contenu attendu pour la BD apres le test
    

  Pour chaque cas de test _foo on effectue donc le traitement suivant:
         - On execute le programme avec les donnees du cas de test 
           (repertoire/test_foo.input et on conserve les resultats 
           dans un fichier temporaire
         - On verifie (avec diff) si la BD resultante vs. la BD attendue sont les memes
           (repertoire/test_foo.bd-apres)
         - On verifie (avec diff) si les resultats emis (stdout/stderr) sont les memes
           que ceux attendus (repertoire/test_foo.output).
         - On prend note du succes vs. echec

  A la fin, un sommaire est produit sur le nombre de cas de tests executes, reussis et echoues.
EOF
}

#######################################################
# Quelques fonctions auxiliaires.
#######################################################

function pluriel {
    if [[ $1 -ge 2 ]]; then
        echo ${2}s
    else
        echo ${2}
    fi
}

function generer_sommaire {
    nbTests=$1
    nbSucces=$2
    nbEchecs=$3
    printf "Sommaire: %d %s; " $nbTests $( pluriel $nbTests test )
    printf "%d %s %s; " $nbSucces $( pluriel $nbSucces test ) $( pluriel $nbSucces reussi )
    printf "%d %s %s\n" $nbEchecs $( pluriel $nbEchecs test ) $( pluriel $nbEchecs echoue )
}

#
function verifier_arguments {
    # Si aucun argument, on affiche l'usage mais sans signaler d'erreur
    [[ $# == 0 ]] && usage && exit 0

    # Il doit y avoir au moins un argument et au plus 4.
    [[ $# -ge 1 && $# -le 4 ]] || erreur_nb_arguments

    # Il peut y avoir une option (flag) "--test=..."
    prefixe=test
    if [[ $1 =~ --test= ]]; then
        prefixe=${1#--test=}
        shift
    fi

    # Il peut y avoir une option (flat) "--bd=..."
    bd=.bd.txt
    if [[ $1 =~ --bd= ]]; then
        bd=${1#--bd=}
        shift
    fi

    # Le programme doit etre specifie et doit etre executable.
    [[ $# -ge 1 ]] || erreur_nb_arguments
    programme=$1
    [[ -e $programme ]] || erreur "Fichier '$programme' n'existe pas"
    [[ ! -d $programme ]] || erreur "Fichier '$programme' est un repertoire, pas un executable!"
    [[ -f $programme ]] && [[ -x $programme ]] || erreur "Fichier '$programme' pas executable; \$@ = "$@""
    shift

    # Le repertoire doit etre un repertoire
    [[ $# -ge 1 ]] || erreur_nb_arguments
    repertoire=$1 && shift  # Argument repertoire specifie.
    [[ -d $repertoire ]] || erreur "Fichier $repertoire pas un repertoire"

    # On peut aussi specifier un patron pour executer uniquement
    # certains tests.
    if [[ $# -ge 1 ]]; then
        wip=$1; shift
    fi

    # On verifie qu'il n'y a pas d'arguments en trop.
    [[ $# == 0 ]] || erreur_nb_arguments
}

#######################################################
# La principale fonction, qui execute un test.
#######################################################

# Execute le programme ($1) sur un test ($2).
# Pour chaque test execute avec succes, on doit emettre un '.'
function executer_test {
    programme=$1
    test=${2%%.input}  # Vrai nom du test = partie avant .input.

    [[ -f $test.arguments ]] && args=$( cat $test.arguments )

    # On prepare la bd.
    cp -f $test.bd-avant $bd
    # On execute le test.
    
    debug "$programme $args < $test.input > obtenu.output 2>&1"

    $programme $args <$test.input >obtenu.output 2>&1

    # On verifie l'etat de la BD pour savoir si succes ou echec.
    test_ok=0
    if [[ -f $test.bd-avant ]] && ! diff $test.bd-apres $bd >& differences.txt 2>&1; then
        echo "*** Test echoue: $test ***" >> $differences
        echo "diff $test.bd-apres $bd" >> $differences
        cat differences.txt >> $differences
        test_ok=1
    fi

    # On verifie la sortie pour savoir si succes ou echec.
    rm -f differences.txt
    if ! diff -iwB $test.output obtenu.output >& differences.txt 2>&1; then
        [[ $test_ok == 0 ]] && echo "*** Test echoue: $test ***" >> $differences
        echo "diff $test.output obtenu.output" >> $differences
        cat differences.txt >> $differences
        echo "" >> $differences
        test_ok=1
    fi

    if [[ $test_ok == 0 ]]; then
        echo -n "."
    else
        echo -n "F"
        echo "" >> $differences
    fi

    [[ -z $DEBUG ]] && rm -f obtenu.output differences.txt

    # On retourne le statut.
    return $test_ok
}


#######################################################
#######################################################
# Le programme principal
#######################################################
#######################################################

# On verifie les arguments.
verifier_arguments "$@"

# A ce point, $programme et $repertoire sont correctement definis
# donc peut etre utilises dans les instructions qui suivent.
debug "# $0 --test=$prefixe $programme $repertoire"

# On execute les tests
nbTests=0
nbSucces=0
nbEchecs=0

# On prepare le fichier qui contiendra toutes les differences
# detectees pendant l'un ou l'autre des tests.
differences=les-differences.txt
touch $differences

for test in $( find $repertoire -name "$prefixe*.input" )
do
    # On verifie le wip, si specifie.
    [[ $wip ]] && [[ ! ${test##$repertoire/$prefixe} =~ $wip ]] && continue

    (( nbTests += 1 ))
    if executer_test $programme $test
    then
       (( nbSucces += 1 ))
    else
       (( nbEchecs += 1 ))
    fi
done
echo ""  # Fin des "."

[[ $nbTests != 0 ]] || erreur "Aucun test n'a ete execute. Verifier le repertoire '$repertoire'!?"


[[ -s $differences ]] && cat $differences

rm -r $differences

generer_sommaire $nbTests $nbSucces $nbEchecs

[[ $nbEchecs == 0 ]]


