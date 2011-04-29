<%@ WebHandler Language="C#" Class="vetoken" %>

using System;
using System.IO;
using System.Web;
using System.Collections.Generic;
using System.Web.Caching;
using System.Collections.Specialized;
using System.Net;

public class vetoken : IHttpHandler 
{
    // set your VE credentials
    private string userName = "";
    private string password = "";
    
    // set your allowed referers
    // For ex.: "http://www.esri.com/myapp/"
    private string[] refererURLs = { 
                                     "" 
                                   };
    
        
    public void ProcessRequest(HttpContext context)
    {
        this.context = context;

        if (!ValidateRequest())
            return;

        // Send the request to the server
        WebResponse serverResponse = null;
        try
        {
            WebRequest request = GetRequest();
            serverResponse = request.GetResponse();
        }
        catch (WebException webExc)
        {
            WriteJsonError(((HttpWebResponse)webExc.Response).StatusCode.ToString(), webExc.Message, "");
            return;
        }

        SendResponseToClient(serverResponse);
    }

    public bool IsReusable
    {
        get { return false; }
    }    
    
    protected bool ValidateRequest()
    {
        //if (IsRefererAllowed == false)
        //    return WriteJsonError("403", "Referer URL is not allowed", "");

        return true;

    }

    protected bool IsRefererAllowed
    {
        get
        {
            string referer = this.context.Request.ServerVariables["HTTP_REFERER"];
            if (string.IsNullOrEmpty(referer) == true)
                return false;
            
            for (int i = 0; i < this.refererURLs.Length; i++)
            {
                if (referer.StartsWith(refererURLs[i]))
                    return true;
            }

            return false;
        }
    }

    protected WebRequest GetRequest()
    {
        HttpWebRequest request = (HttpWebRequest)WebRequest.Create(new Uri(this.TargetURL));
        request.Method = "GET";
        request.AllowAutoRedirect = true;
        request.Referer = String.Join(",", refererURLs);

        return request;
    }

    protected void SendResponseToClient(WebResponse serverResponse)
    {
        // Set up the response to the client
        this.context.Response.ContentType = serverResponse.ContentType;
        using (Stream byteStream = serverResponse.GetResponseStream())
        {
            using (StreamReader sr = new StreamReader(byteStream))
            {
                string strResponse = sr.ReadToEnd();
                if (string.IsNullOrEmpty(Callback) == false)
                    strResponse = string.Format("{0}({1});", Callback, strResponse);

                this.context.Response.Write(strResponse);
            }
            serverResponse.Close();
        }
        this.context.Response.End();
    }

    #region Properties
    public string UserName
    {
        get { return this.userName; }
    }
    
    public string Password
    {
        get { return this.password; }
    }
                                  
    public string Environment
    {
        get { return string.IsNullOrEmpty(RequestParameters[Constants.Environment]) ? "staging" : RequestParameters[Constants.Environment]; }        
    }

    public string IPType
    {
        get { return RequestParameters[Constants.IPType]; }        
    }

    public string Duration
    {
        get { return RequestParameters[Constants.Duration]; }        
    }

    public string Callback
    {
        get { return RequestParameters[Constants.Callback]; }
    }
    #endregion

    #region Internal Implementation
    // Private internal variables / methods
    private HttpContext context = null;
    private NameValueCollection requestParameters = null;
    
    // These three request parameters are required: environment, duration, iptype
    private string duration;    //Must be between 15 and 480
    private string environment; //Either 'production' or 'staging'
    private string ipType;      //Either 'client' or 'server'

    private bool WriteJsonError(string code, string message, string details)
    {
        string jsonError = "{\"error\":{\"code\":" + code + ",\"message\":\"" + message + "\",\"details\":[]}}";

        this.context.Response.Output.Write(jsonError);
        this.context.Response.End();

        return false;
    }
  
    private NameValueCollection RequestParameters
    {
        get
        {
            if (requestParameters == null)
            {
                if (this.context.Request.HttpMethod == "POST" && this.context.Request.Form.Count > 0)
                    // For POST
                    requestParameters = this.context.Request.Form;
                else
                    // For GET
                    requestParameters = this.context.Request.QueryString;
            }

            return requestParameters;
        }
    }

    private string TargetURL
    {
        get
        {
            string url = string.Format("https://serverapi.arcgisonline.com/veaserver/{0}/token/getToken", this.Environment);
            url += "?user=" + System.Web.HttpUtility.UrlEncode(this.UserName);
            url += "&password=" + System.Web.HttpUtility.UrlEncode(this.Password);
            url += "&duration=" + System.Web.HttpUtility.UrlEncode(this.Duration);
            url += "&iptype=" + System.Web.HttpUtility.UrlEncode(this.IPType);
            if (string.Compare(this.IPType, "client", true) == 0)
                url += "&clientip=" + this.context.Request.UserHostAddress;

            return url;
        }
    }
    #endregion
}

#region Constants
//
// Constants used to extract request parameters
//
internal class Constants
{
    public const string Environment = "environment";
    public const string Duration    = "duration";
    public const string IPType      = "iptype";
    public const string Callback    = "callback";
    public const string Referer     = "referer";
};
#endregion
