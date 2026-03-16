<#
cs-CZ locale data pack - Czech Republic / Ceska republika
#>
Register-SldgLocaleInternal -Name 'cs-CZ' -Data @{
	# Person names - typical Czech names
	MaleNames   = @('Jan', 'Petr', 'Josef', 'Pavel', 'Martin', 'Tomas', 'Jakub', 'Michal', 'Lukas', 'Ondrej', 'David', 'Filip', 'Vojtech', 'Adam', 'Matej', 'Daniel', 'Marek', 'Jiri', 'Vaclav', 'Ales', 'Roman', 'Radek', 'Zdenek', 'Karel', 'Milan', 'Stanislav', 'Frantisek', 'Vladimir', 'Jaroslav', 'Miroslav', 'Ivan', 'Ladislav', 'Robert', 'Libor', 'Patrik', 'Richard', 'Vlastimil', 'Dominik', 'Antonin', 'Vitezslav', 'Rostislav', 'Bohuslav', 'Oldrich', 'Radim', 'Miloslav', 'Dalibor', 'Radomir', 'Lubomir', 'Bretislav', 'Eduard')
	FemaleNames = @('Jana', 'Marie', 'Eva', 'Anna', 'Hana', 'Lenka', 'Katerina', 'Lucie', 'Petra', 'Veronika', 'Martina', 'Tereza', 'Marketa', 'Michaela', 'Barbora', 'Klara', 'Simona', 'Andrea', 'Monika', 'Ivana', 'Jitka', 'Alena', 'Dana', 'Helena', 'Irena', 'Dagmar', 'Zuzana', 'Vera', 'Renata', 'Blanka', 'Gabriela', 'Milena', 'Radka', 'Olga', 'Denisa', 'Nikola', 'Kristyna', 'Pavla', 'Libuse', 'Romana', 'Jaroslava', 'Miroslava', 'Vendula', 'Sarka', 'Stanislava', 'Vladimira', 'Daniela', 'Adela', 'Natalie', 'Karolina')
	LastNames   = @('Novak', 'Svoboda', 'Novotny', 'Dvorak', 'Cerny', 'Prochazka', 'Kucera', 'Vesely', 'Horak', 'Nemec', 'Marek', 'Pokorny', 'Pospisil', 'Hajek', 'Jelinek', 'Kral', 'Ruzicka', 'Benes', 'Fiala', 'Sedlacek', 'Nguyen', 'Dolezal', 'Zeman', 'Kolar', 'Navratil', 'Sykora', 'Maly', 'Vlcek', 'Urban', 'Blaha', 'Kopecky', 'Konecny', 'Adamek', 'Holub', 'Vanek', 'Stepanek', 'Bartos', 'Simek', 'Polak', 'Cada', 'Vodicka', 'Palecek', 'Kovar', 'Hruska', 'Kubik', 'Machacek', 'Tuma', 'Strnad', 'Beran', 'Vavra')

	# Address - Czech cities with PSC (postal code) prefixes
	StreetNames = @('Hlavni', 'Narodni', 'Masarykova', 'Husova', 'Nerudova', 'Palackeho', 'Komenskeho', 'Sokolska', 'Revolucni', 'Na Prikope', 'Vaclavske', 'Karlova', 'Dlouha', 'Skolni', 'Zahradni', 'Sportovni', 'Lesni', 'Polni', 'Lidická', 'Jiráskova', 'Ruzova', 'Kvetinova', 'Nádrazni', 'Prumyslova', 'Tyrsova')
	StreetTypes = @('ulice', 'trida', 'namesti', 'nábrezi')
	Locations   = @(
		@{ City = 'Praha'; State = 'Hlavni mesto Praha'; ZipPrefix = '100' }
		@{ City = 'Brno'; State = 'Jihomoravsky'; ZipPrefix = '602' }
		@{ City = 'Ostrava'; State = 'Moravskoslezsky'; ZipPrefix = '700' }
		@{ City = 'Plzen'; State = 'Plzensky'; ZipPrefix = '301' }
		@{ City = 'Liberec'; State = 'Liberecky'; ZipPrefix = '460' }
		@{ City = 'Olomouc'; State = 'Olomoucky'; ZipPrefix = '779' }
		@{ City = 'Ceske Budejovice'; State = 'Jihocesky'; ZipPrefix = '370' }
		@{ City = 'Hradec Kralove'; State = 'Kralovehradecky'; ZipPrefix = '500' }
		@{ City = 'Usti nad Labem'; State = 'Ustecky'; ZipPrefix = '400' }
		@{ City = 'Pardubice'; State = 'Pardubicky'; ZipPrefix = '530' }
		@{ City = 'Zlin'; State = 'Zlinsky'; ZipPrefix = '760' }
		@{ City = 'Kladno'; State = 'Stredocesky'; ZipPrefix = '272' }
		@{ City = 'Most'; State = 'Ustecky'; ZipPrefix = '434' }
		@{ City = 'Karlovy Vary'; State = 'Karlovarsky'; ZipPrefix = '360' }
		@{ City = 'Jihlava'; State = 'Vysocina'; ZipPrefix = '586' }
		@{ City = 'Teplice'; State = 'Ustecky'; ZipPrefix = '415' }
		@{ City = 'Frydek-Mistek'; State = 'Moravskoslezsky'; ZipPrefix = '738' }
		@{ City = 'Opava'; State = 'Moravskoslezsky'; ZipPrefix = '746' }
		@{ City = 'Karvina'; State = 'Moravskoslezsky'; ZipPrefix = '733' }
		@{ City = 'Chomutov'; State = 'Ustecky'; ZipPrefix = '430' }
	)
	Countries     = @('Ceska republika', 'CZ', 'CZE')
	ZipFormat     = '{Prefix} {Suffix:D2}'
	AddressFormat = '{Street} {Number}'
	StateLabel    = 'Kraj'

	# Contact - Czech domains
	EmailDomains = @('seznam.cz', 'email.cz', 'centrum.cz', 'volny.cz', 'atlas.cz', 'post.cz', 'tiscali.cz', 'outlook.cz', 'gmail.com', 'yahoo.com', 'firma.cz', 'podnik.cz', 'spolecnost.cz')

	PhoneFormat = @{
		AreaCodes = @('601', '602', '603', '604', '605', '606', '607', '608', '702', '703', '704', '720', '721', '722', '723', '724', '725', '726', '727', '728', '729', '730', '731', '732', '733', '734', '735', '736', '737', '770', '771', '772', '773', '774', '775', '776', '777', '778', '779')
		Formats   = @{
			Standard      = '+420 {Area} {Exchange} {Subscriber}'
			International = '+420-{Area}-{Exchange}-{Subscriber}'
			Simple        = '{Area}{Exchange}{Subscriber}'
		}
		ExchangeMin    = 100
		ExchangeMax    = 999
		SubscriberMin  = 100
		SubscriberMax  = 999
	}

	# Business - Czech companies
	CompanyPrefixes = @('Cesky', 'Moravsky', 'Prazsky', 'Narodni', 'Prvni', 'Stredoevropsky', 'Spolecnost', 'Skupina', 'Digital', 'Global', 'Smart', 'Tech', 'Euro', 'Prima', 'Meta', 'Nova', 'Pro', 'Ultra', 'Mega', 'Auto')
	CompanyCores    = @('Systemy', 'Reseni', 'Sluzby', 'Technologie', 'Stavby', 'Strojirny', 'Energetika', 'Logistika', 'Komunikace', 'Finance', 'Data', 'Software', 'Holding', 'Trade', 'Invest', 'Development', 'Production', 'Engineering', 'Consulting', 'Management')
	CompanySuffixes = @('s.r.o.', 'a.s.', 'v.o.s.', 'k.s.', 'SE', 'spol. s r.o.')
	Departments     = @('Vyvoj', 'Obchod', 'Marketing', 'Lidske zdroje', 'Finance', 'Ucetnictvi', 'Pravni oddeleni', 'Provoz', 'Zakaznicka podpora', 'Vyzkum a vyvoj', 'Produktovy management', 'Kontrola kvality', 'IT', 'Bezpecnost', 'Administrativa', 'Logistika', 'Nakup', 'Skoleni', 'Compliance', 'Obchodni rozvoj')
	JobTitles       = @('Softwarovy vyvojar', 'Senior programator', 'Projektovy manazer', 'Obchodni analytik', 'Datovy analytik', 'Produktovy manazer', 'Obchodni zastupce', 'Key Account Manager', 'Marketingovy specialista', 'HR specialista', 'Financni analytik', 'Provozni manazer', 'Inzenyr kvality', 'Technicky vedouci', 'Architekt', 'Konzultant', 'Reditel', 'Namestek reditele', 'Technicky reditel', 'Financni reditel', 'Spravce databazi', 'Systemovy administrator', 'DevOps inzenyr', 'Bezpecnostni analytik', 'UX designer', 'Technicky redaktor', 'Specialista podpory', 'Referent nakupu', 'Compliance manazer', 'Vedouci tymu')
	Industries      = @('Technologie', 'Zdravotnictvi', 'Finance', 'Prumysl', 'Obchod', 'Vzdelavani', 'Doprava', 'Energetika', 'Telekomunikace', 'Reality', 'Pojistovnictvi', 'Poradenstvi', 'Automobilovy prumysl', 'Farmacie', 'Potravinarstvi', 'Stavebnictvi', 'Media', 'Letectvi', 'Zemedelstvi', 'Pohostinstvi')

	# Czech-specific identifiers
	NationalIdFormat = '{BirthYear:D2}{BirthMonth:D2}{BirthDay:D2}/{Suffix:D4}'   # Rodne cislo
	TaxIdFormat      = 'CZ{ICO:D8}'   # DIC format
	IBANCountries    = @('CZ')
	Currencies       = @('CZK', 'EUR', 'USD')

	# Text
	Statuses   = @('Aktivni', 'Neaktivni', 'Cekajici', 'Schvaleno', 'Zamitnuto', 'Zruseno', 'Dokonceno', 'Probiha', 'Pozastaveno', 'Koncept', 'Archivovano', 'Uzavreno', 'Otevreno', 'Novy', 'Zpracovava se')
	Genders    = @('Muz', 'Zena', 'Nespecifikovano')
	Categories = @('Typ A', 'Typ B', 'Typ C', 'Standardni', 'Premium', 'Zakladni', 'Pokrocily', 'Profesionalni', 'Enterprise', 'Startovni')
}
