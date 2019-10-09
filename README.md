# Gestion du RBAC pour un nouveau projet

Ce script permet de créer un nouveau projet dans un cluster Docker :
- création de l'organisation dans Docker Enterprise
- création des teams avec mapping vers les groupes LDAP
- création des rôles kubernetes observers, contributors et operators
- création des namespaces pour le projet (int / rec / pprod / prod)
- affectation des droits : (ex : team app/observers-int --> rôle observer --> namespace app-int)
- création des namespaces dans la DTR

:warning: ce script ne réalise les actions que dans Docker Enterprise. Pour créer un nouveau projet, il faut aussi créer les projets dans Gitlab, ainsi que l'organisation dans le LDAP.

L'initialisation d'un nouveau projet s'effectue en 2 étapes :
1/ Génération des fichiers qui décrivent l'ensemble des ressources à créer dans le cluster à partir de fichiers template
2/ Application des fichiers sur chaque cluster (hors prod et prod) pour créer les ressources

Vous devez connaitre le CODE_PROJET_CMDB qui sera utilisé dans le nom des ressources créées

## Génération des fichiers

Exécuter le script de génération des fichiers :

    ./init_rbac.sh CODE_PROJET_CMDB

Ce script va générer 2 arborescences :
- ./rbac/CODE_PROJET_CMDB/horsprod
- ./rbac/CODE_PROJET_CMDB/prod   

Après avoir vérifier et éventuellement modifier les fichiers générés, il faut maintenant appliquer les fichiers sur chaque cluster

## Application des fichiers
 
 ### Cluster de hors production
 Tout d'abord, sourcer le bundle du cluster de hors production pour diriger l'ensemble des commandes `kubectl` vers le cluster de hors production.  
Vérifier ensuite le fichier `cluster_horsprod.properties` qui contient les informations de connexion au cluster.
Appliquer les fichiers générés à l'étape précédente en éxécutant la commande suivante :

    ./apply_rbac.sh cluster_horsprod.properties ./rbac/CODE_PROJET_CMDB/horsprod

 ### Cluster de production
 Les mêmes étapes sont à répéter pour le cluster de production :
 - sourcer le bundle de production
 - vérifier le fichier `cluster_prod.properties`
 - appliquer les fichiers générés en éxécutant la commande suivante :

```
./apply_rbac.sh cluster_prod.properties ./rbac/CODE_PROJET_CMDB/prod
```

