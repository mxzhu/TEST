﻿using ESOP.Utility;
using InsiderTrading.Common;
using InsiderTrading.Models;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Security.Claims;
using System.Web;
using System.Web.Mvc;

namespace InsiderTrading.Controllers
{
    public class ADAssertionConsumerController : Controller
    {
        // GET: ADAssertionConsumer
        public ActionResult Index()
        {
            string adfsUrl = ConfigurationManager.AppSettings["ADFSUrl"].ToString();
            return Redirect(adfsUrl);

            //return View();
        }

        [AllowAnonymous]
        public ActionResult AssertionConsumer()
        {
            try
            {
                string emailId = string.Empty;
                string companyName = string.Empty;
                string employeeId = string.Empty;
                string windowsAccountName = string.Empty;
                string Emplist = string.Empty;
                //string empEmail = "anand.kulkarni@esopdirect.com";
                //string empId = empployeeId = "Halt1";

                WriteToFileLog.Instance("ADFS").Write("Called AssertionConsumer Method on ADAssertionConsumerController.");
                
                ClaimsIdentity principal = HttpContext.User.Identity as ClaimsIdentity;
                if (null != principal)
                {
                    int countClaims = 0;
                    foreach (Claim claim in principal.Claims)
                    {
                        Emplist += "CLAIM TYPE: " + claim.Type + "; CLAIM VALUE: " + claim.Value + "</br>";
                        if (claim.Type.Contains("name"))
                        {
                            if (countClaims == 0)
                            {
                                employeeId = claim.Value;
                                countClaims++;
                            }
                        }
                        if (claim.Type.Contains("emailaddress"))
                        {
                            emailId = claim.Value;
                        }
                        if (claim.Type.Contains("windowsaccountname"))
                        {
                            windowsAccountName = claim.Value;
                        }
                    }
                }
                WriteToFileLog.Instance("ADFS").Write(Emplist);
               // WriteToFileLog.Instance("ADFS").Write("Claims: " + "Employee Id- " + employeeId + " Email Id- " + emailId + " Windows Account Name- " + windowsAccountName);
                Hashtable ht_Parmeters = new Hashtable();
                //employeeId = "Halt1";
                companyName = Convert.ToString(Cryptography.DecryptData(ConfigurationManager.AppSettings["ADFSCompanyDBName"].ToString()));
                ht_Parmeters.Add(CommonConstant.s_AttributeEmployeeId, employeeId);
                ht_Parmeters.Add(CommonConstant.s_AttributeEmail, "");
                ht_Parmeters.Add(CommonConstant.s_AttributeComapnyName, companyName);
                ViewBag.RequestStatus = CommonConstant.sRequestStatusSAML_RESPONSE;
                ViewBag.IsRequestValid = false;
                using (SSOModel SSOModel = new SSOModel())
                {
                    SSOModel.SetupLoginDetails(ht_Parmeters);
                    ViewBag.IsRequestValid = true;
                    Session["loginStatus"] = 1;
                    HttpContext.Session.Add("UserCaptchaText", string.Empty);
                    HttpContext.Session.Add(ConstEnum.SessionValue.CookiesValidationKey, "");
                    HttpContext.Session.Add("formField", "130");
                    WriteToFileLog.Instance(ConfigurationManager.AppSettings["ADFS"].ToString()).Write("Before Redirect.");
                    return RedirectToAction("Index", "Home", new { acid = Convert.ToString(0) });
                }
            }
            catch (Exception exception)
            {
                ViewBag.RequestStatus = exception.Message.ToString();
            }

            return View();

        }
    }
}