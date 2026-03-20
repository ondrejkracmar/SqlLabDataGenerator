namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a group object formatted for Microsoft Entra ID import.
    /// </summary>
    public class EntraIdGroup
    {
        /// <summary>The display name of the group.</summary>
        public string DisplayName { get; set; }

        /// <summary>The mail nickname.</summary>
        public string MailNickname { get; set; }

        /// <summary>Whether the group is mail-enabled.</summary>
        public bool MailEnabled { get; set; }

        /// <summary>Whether the group is security-enabled.</summary>
        public bool SecurityEnabled { get; set; }

        /// <summary>Group types (e.g., ['Unified'] for Microsoft 365 groups).</summary>
        public string[] GroupTypes { get; set; }

        /// <summary>Group description.</summary>
        public string Description { get; set; }

        /// <summary>Department associated with the group.</summary>
        public string Department { get; set; }

        /// <summary>Initializes a new instance of the <see cref="EntraIdGroup"/> class.</summary>
        public EntraIdGroup() { }
    }
}
