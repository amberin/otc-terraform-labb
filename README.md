Denna konfiguration nyttjar Terraform workspaces. Namnet på aktuell
workspace inkluderas via en variabel i användarnamn och projektnamn
vid kommunikation med OTC.

Inloggningsuppgifter behöver sättas antingen via miljövariabler (t ex
TF_VAR_OTC_ACCESS_KEY, TF_VAR_OTC_SECRET_KEY) eller i .tfvars-filer
som kan aktiveras eller inaktiveras vid behov. I det senare fallet får
filerna förstås inte checkas in i source control, och måste förvaras
säkert.

Eftersom det aktiva workspacet avgör vilken användare och vilket
projekt i OTC som används, så är risken liten för att råka göra
förändringar i prod av misstag. Även om man skulle råka glömma att man
har bytt workspace till prod, så kommer de credentials som för
närvarande är satta inte att fungera ihop med fel användare och
projekt.

# Komma igång från scratch

Följande steg är nödvändiga med ett nytt OTC-konto:

1. IAM-inställningar
    1. Skapa projekten "test", "prod" i relevant region.
    1. Skapa user groups "terraform-test", "terraform-prod".
    1. Tilldela user groups relevanta behörigheter i respektive projekt (t ex "CCE Administrator", "VPC Admin")
    1. Skapa användarna "terraform-test", "terraform-prod" och knyt till resp user group.
    1. Skapa access keys för de två användarna, spara secret keys på säker plats.
1. Möjliggör remote storage av state file
    1. Skapa en OBS bucket med ACL "private"
    1. Skapa två policies på OBS bucket för att ge användarna terraform-(test|prod) fulla rättigheter
        1. en customized policy på bucket-nivå som tillåter action "*".
        1. en read and write policy för resource "*".
1. `terraform init`
1. `terraform workspace new prod`
1. `terraform workspace new test`
