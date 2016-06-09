﻿using log4net;
using Sequencing.WeatherApp.Controllers.OAuth;
using Sequencing.WeatherApp.Controllers.PushNotification;
using Sequencing.WeatherApp.Controllers.UserNotification;
using Sequencing.WeatherApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;

namespace Sequencing.WeatherApp.Controllers.DaoLayer
{
    /// <summary>
    /// Service which implements push notification logic
    /// </summary>
    public class DefaultPushNotificationService : IPushNotificationService
    {
        private OAuthTokenDaoFactory oauthFactory = new OAuthTokenDaoFactory();
        private MSSQLDaoFactory mssqlDaoFactory = new MSSQLDaoFactory();
        private ISettingService settingsService = new UserSettingService();

        private log4net.ILog logger = LogManager.GetLogger(typeof(DefaultPushNotificationService));

        /// <summary>
        /// Subscribe user to get push message
        /// </summary>
        /// <param name="deviceToken"></param>
        /// <param name="deviceType"></param>
        /// <param name="accessToken"></param>
        public void Subscribe(string deviceToken, DeviceType deviceType, string accessToken)
        {
            string userName = new AuthWorker(Options.OAuthUrl, Options.OAuthRedirectUrl, Options.OAuthSecret,
                Options.OAuthAppId).GetUserInfo(accessToken).username;

            // checking for token validity
            if (userName != null)
            {
                var sendInfo = mssqlDaoFactory.GetSendInfoDao().Find(userName);

                if (sendInfo != null)
                    settingsService.SubscribePushNotification(sendInfo.Id, deviceToken, deviceType);
            }
            else
                logger.InfoFormat("Invalid access token");
        }

        /// <summary>
        /// Unsubscribe user from push message
        /// </summary>
        /// <param name="token"></param>
        public void Unsubscribe(string token)
        {
            mssqlDaoFactory.GetDeviceTokenDao().DeleteToken(token);
        }

        /// <summary>
        /// Sends push message to subscribed user device
        /// </summary>
        /// <param name="userId"></param>
        /// <param name="deviceType"></param>
        /// <param name="token"></param>
        /// <param name="message"></param>
        public void Send(Int64 userId, DeviceType deviceType, string token, string message)
        {
            PushMessageSender pushMessageSender = GetPushMessageSender(deviceType);

            if (pushMessageSender == null)
            {
                logger.Error(string.Format("Device type: {0} is not supported", deviceType));
                return;
            }

            pushMessageSender.SendPushNotification(token, message, userId);
        }


        /// <summary>
        /// Sends push message to all user devices 
        /// </summary>
        /// <param name="userId"></param>
        /// <param name="message"></param>
        public void Send(Int64 userId, string message)
        {
            List<DeviceToken> deviceTokensInfo = mssqlDaoFactory.GetDeviceTokenDao().Select(userId);

            foreach (DeviceToken token in deviceTokensInfo)
            {
                Send(userId, token.deviceType.Value, token.token, message);
            }
        }

        /// <summary>
        /// Adds device token to database
        /// </summary>
        /// <param name="userId"></param>
        /// <param name="token"></param>
        /// <param name="deviceType"></param>
        public void SubscribeDeviceToken(Int64 userId, string token, DeviceType deviceType)
        {
            try
            {
                if (IsTokenSubscribed(token))
                    return;

                DeviceToken devInfo = new DeviceToken
                {
                    userId = userId,
                    subscriptionDate = DateTime.Now.Date,
                    deviceType = deviceType,
                    token = token
                };

                mssqlDaoFactory.GetDeviceTokenDao().SaveToken(devInfo);
            }
            catch (Exception e)
            {
                logger.Error(e);
            }

        }

        /// <summary>
        /// Checks whether user is subscribed to get push notifications
        /// </summary>
        /// <param name="userId"></param>
        /// <returns></returns>
        public bool IsUserSubscribed(Int64 userId)
        {
            if (mssqlDaoFactory.GetDeviceTokenDao().SelectCount(userId) > 0)
                return true;

            return false;
        }

        /// <summary>
        /// Checks whether user devise is subscribed to get push notifications
        /// </summary>
        /// <param name="token"></param>
        /// <returns></returns>
        public bool IsTokenSubscribed(string token)
        {
            if (mssqlDaoFactory.GetDeviceTokenDao().FindToken(token) == null)
                return false;

            return true;
        }


        /// <summary>
        /// Fetches user device tokens from database
        /// </summary>
        /// <param name="userId"></param>
        /// <param name="deviceType"></param>
        /// <returns></returns>
        public List<string> FetchUserDeviceTokens(Int64 userId, DeviceType deviceType)
        {
            return mssqlDaoFactory.GetDeviceTokenDao().GetUserTokens(userId, deviceType).ToList();
        }


        /// <summary>
        /// Refreshes expired device token in DB
        /// </summary>
        /// <param name="oldId"></param>
        /// <param name="newId"></param>
        public void RefreshDeviceToken(string oldId, string newId)
        {
            mssqlDaoFactory.GetDeviceTokenDao().UpdateToken(oldId, newId);
        }

        /// <summary>
        /// Determines device type
        /// </summary>
        /// <param name="deviceType"></param>
        /// <returns></returns>
        private PushMessageSender GetPushMessageSender(DeviceType deviceType)
        {
            switch (deviceType)
            {
                case DeviceType.IOS:
                    return new IosPushMessageSender();

                case DeviceType.Android:
                    return new AndroidPushMessageSender();
            }

            return null;
        }
    }
}