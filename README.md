Denna konfiguration använder separata Terraform workspaces som
motsvarar en test- och en produktionsmiljö. Tanken är att de ska
skilja sig så lite som möjligt från varandra. De får gärna motsvaras
av två separata Git-grenar, men dessa bör inte ha permanenta
skillnader. Det är bättre att koden ser likadan ut, men innehåller
logik eller variabler som beskriver skillnaderna mellan test och prod
(nyttja variabeln ${terraform.workspace}).

Namnet på aktuell workspace inkluderas via en variabel i användarnamn
och projektnamn vid kommunikation med OTC.

Inloggningsuppgifter för de två olika miljöerna behöver sättas
antingen via miljövariabler (t ex TF_VAR_OTC_ACCESS_KEY,
TF_VAR_OTC_SECRET_KEY) eller i .tfvars-filer som kan aktiveras eller
inaktiveras vid behov. I det senare fallet får filerna förstås inte
checkas in i source control, och måste förvaras säkert.

Eftersom det aktiva workspacet avgör vilken användare och vilket
projekt i OTC som används, så är det osannolikt att man råkar göra
förändringar i prod av misstag. Även om man skulle råka glömma att man
har bytt workspace till prod, så kommer de credentials som för
närvarande är satta inte att fungera ihop med fel användare och
projekt. Detta är den enda anledningen till att jag valt att skapa två
separata användare -- att minimera risken för oavsiktliga ändringar i
produktionsmiljön.

# Inloggningsuppgifter för state file backend

En nackdel med att använda OBS bucket för att lagra state file är att
Terraform inte har formellt stöd för OBS som storage backend. Man
måste lura Terraform att det är en AWS S3-bucket som man använder (se
konfigurationsavsnittet terraform.backend.s3). Det innebär att access key
och secret key för auth mot bucket måste sättas i ytterligare
miljövariabler, som läses av Terraforms S3-klient (se instruktioner
nedan).

# Komma igång från scratch

Följande steg är nödvändiga med ett nytt OTC-konto:

1. IAM-inställningar
    1. Skapa projekten "test", "prod" i relevant region.
    1. Skapa user groups "terraform-test", "terraform-prod".
    1. Tilldela dina user groups följande behörigheter i respektive
       projekt:
        - "VPC Admin"
        - "CCE Administrator"
        - "CCE Admin"
    1. Skapa användarna "terraform-test", "terraform-prod" och knyt
       till resp user group.
    1. Skapa access keys för de två användarna. Spara secret keys på
       säker plats.
1. Möjliggör remote storage av state file
    1. Skapa en OBS bucket med ACL "private"
    1. Skapa två policies på denna OBS bucket för att ge både test-
       och prod-användaren (`terraform-test`, `terraform-prod`) fulla
       rättigheter:
        1. en customized policy på bucket-nivå som tillåter action "*".
        1. en read and write policy för resource "*".
    1. Sätt miljövariablerna AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
       i ditt skal med samma värde som AK/SK för någon av användarna
       terraform-(test|prod). (Samma katalog med state-information
       används av båda användarna.)
1. `terraform init`
1. `terraform workspace new prod`
1. `terraform workspace new test`
1. `terraform workspace select test`
1. I OTC:s webbkonsol, gå in på service "CCE" och påbörja guiden för
   att starta ett kluster för ett givet projekt/region. Då får du
   möjlighet att ge projektet behörighet till alla resurser som krävs
   för att administrera CCE-kluster.
1. `terraform plan` osv
