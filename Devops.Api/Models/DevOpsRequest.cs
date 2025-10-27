namespace Devops.Api.Models
{
    public class DevOpsRequest
    {
        public string Message { get; set; } = string.Empty;
        public string To { get; set; } = string.Empty;
        public string From { get; set; } = string.Empty;
        public int TimeToLifeSec { get; set; }
    }
}
