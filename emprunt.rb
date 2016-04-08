# -*- coding: utf-8 -*-

ADRESSE_COURRIEL = /([\w\.]*@[\w\.]*)/

#
# Objet pour modeliser un Emprunt d'un livre.
#
# Tous les champs sont immuables (non modifiables) à l'exception du
# champ qui indique si le document est perdu.
#
class Emprunt
  include Comparable

  attr_reader :nom, :courriel, :titre, :auteurs

  def initialize( nom, courriel, titre, auteurs, perdu = false )
    fail "Format invalide de courriel: #{courriel}!?" unless courriel =~ ADRESSE_COURRIEL

    @nom = nom
    @courriel = courriel
    @titre = titre
    @auteurs = auteurs
    @perdu = perdu
  end


  #
  # Formate un emprunt selon les indications spécifiées par le_format:
  #   - %N: Nom de l'emprunteur
  #   - %C: Courriel de l'emprunteur
  #   - %T: Titre du document emprunté
  #   - %A: Auteurs du document emprunté
  #
  # Des indications de largeur, justification, etc. peuvent aussi être
  # spécifiées, par exemple, %-10A, %-.10A, etc.
  #
  def to_s( le_format = nil )
    # Format simple par defaut, pour les cas de tests de base.a
    perdu = perdu? ? ' [[PERDU]]' : ''
    if le_format.nil?
      	return format('%s :: [ %-10s ] "%s"', nom, auteurs, titre) << perdu
	else
		le_format = le_format.gsub /%(-?.?[0-9]*)N/, '%\1s'
		le_format = format(le_format, nom)
		le_format = le_format.gsub /%(-?.?[0-9]*)C/, '%\1s'
		le_format = format(le_format, courriel)
		le_format = le_format.gsub /%(-?.?[0-9]*)T/, '%\1s'
		le_format = format(le_format, titre)
		le_format = le_format.gsub /%(-?.?[0-9]*)A/, '%\1s'
		le_format = format(le_format, auteurs)
  		le_format = le_format.gsub /\\/, ''	
		return le_format << perdu
    end

    fail "Cas non traite: to_s( #{le_format} )"
  end


  #
  # Ordonne les emprunts selon le nom en premier, puis selon le titre.
  #
  def <=>( autre )
	#On vérifie les noms
    case @nom <=> autre.nom
    when 0
      #Les noms sont égaux, on vérifie les titres
      case @titre <=> autre.titre
      when 0
	return 0
      when -1
        return -1
      else
        return 1
      end

    when -1
      return -1

    else
      return 1
    end
  end

  #
  # Indique la perte d'un document.
  #
  def indiquer_perte
    @perdu = true
  end

  # Attribut booleen, donc nom avec '?'.
  def perdu?
    @perdu
  end
end
