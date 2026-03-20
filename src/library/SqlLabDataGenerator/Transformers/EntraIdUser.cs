namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a user object formatted for Microsoft Entra ID import.
    /// </summary>
    public class EntraIdUser
    {
        /// <summary>Whether the account is enabled.</summary>
        public bool AccountEnabled { get; set; }

        /// <summary>The display name.</summary>
        public string DisplayName { get; set; }

        /// <summary>The given (first) name.</summary>
        public string GivenName { get; set; }

        /// <summary>The surname (last name).</summary>
        public string Surname { get; set; }

        /// <summary>The user principal name (UPN).</summary>
        public string UserPrincipalName { get; set; }

        /// <summary>The mail nickname.</summary>
        public string MailNickname { get; set; }

        /// <summary>Usage location for licensing (ISO country code).</summary>
        public string UsageLocation { get; set; }

        /// <summary>Password profile with initial password and change requirement.</summary>
        public object PasswordProfile { get; set; }

        /// <summary>Email address.</summary>
        public string Mail { get; set; }

        /// <summary>Mobile phone number.</summary>
        public string MobilePhone { get; set; }

        /// <summary>Job title.</summary>
        public string JobTitle { get; set; }

        /// <summary>Department.</summary>
        public string Department { get; set; }

        /// <summary>Company name.</summary>
        public string CompanyName { get; set; }

        /// <summary>City.</summary>
        public string City { get; set; }

        /// <summary>State or province.</summary>
        public string State { get; set; }

        /// <summary>Country.</summary>
        public string Country { get; set; }

        /// <summary>Postal code.</summary>
        public string PostalCode { get; set; }

        /// <summary>Street address.</summary>
        public string StreetAddress { get; set; }

        /// <summary>Initializes a new instance of the <see cref="EntraIdUser"/> class.</summary>
        public EntraIdUser() { }
    }
}
