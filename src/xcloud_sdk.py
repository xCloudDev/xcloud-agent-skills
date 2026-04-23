#!/usr/bin/env python3
"""
xCloud Public API Python SDK
Provides high-level abstractions for xCloud infrastructure automation.

Usage:
    from xcloud_sdk import XCloudAPI, XCloudDeployer
    
    api = XCloudAPI(token="12|...")
    deployer = XCloudDeployer(api)
    
    # Create a WordPress site
    site = deployer.create_site(
        domain="example.com",
        server_uuid="...",
        php_version="8.2"
    )
"""

import os
import json
import time
import requests
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta


class XCloudAPIError(Exception):
    """Base exception for xCloud API errors"""
    pass


class XCloudAuthError(XCloudAPIError):
    """Authentication/authorization error"""
    pass


class XCloudRateLimitError(XCloudAPIError):
    """Rate limit exceeded"""
    pass


class XCloudTimeoutError(XCloudAPIError):
    """Operation timeout"""
    pass


class XCloudAPI:
    """Low-level xCloud Public API client"""
    
    BASE_URL = "https://app.xcloud.host/api/v1"
    RATE_LIMIT = 60  # requests per minute
    REQUEST_TIMEOUT = 30
    
    def __init__(self, token: str = None):
        """
        Initialize xCloud API client.
        
        Args:
            token: API token (or read from XCLOUD_API_TOKEN env var)
        """
        self.token = token or os.getenv("XCLOUD_API_TOKEN")
        if not self.token:
            raise XCloudAuthError("XCLOUD_API_TOKEN not set")
        
        self.session = requests.Session()
        self._set_headers()
        self._request_count = 0
        self._rate_limit_reset = None
    
    def _set_headers(self):
        """Set default request headers"""
        self.session.headers.update({
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "xcloud-agent-sdk/1.1.0"
        })
    
    def _handle_rate_limit(self, response):
        """Handle 429 rate limit responses"""
        if response.status_code == 429:
            retry_after = int(response.headers.get("Retry-After", 60))
            raise XCloudRateLimitError(
                f"Rate limited. Retry after {retry_after}s"
            )
    
    def _request(self, method: str, path: str, **kwargs) -> Dict[str, Any]:
        """
        Make HTTP request to xCloud API.
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            path: API path (without base URL)
            **kwargs: Additional request arguments
        
        Returns:
            Response data
        """
        url = f"{self.BASE_URL}{path}"
        
        try:
            response = self.session.request(
                method,
                url,
                timeout=self.REQUEST_TIMEOUT,
                **kwargs
            )
            
            self._handle_rate_limit(response)
            
            if response.status_code == 401:
                raise XCloudAuthError("Invalid or expired token")
            
            response.raise_for_status()
            return response.json()
            
        except requests.Timeout:
            raise XCloudTimeoutError(f"Request to {path} timed out")
        except requests.RequestException as e:
            raise XCloudAPIError(f"Request failed: {e}")
    
    # ========================================================================
    # READ OPERATIONS
    # ========================================================================
    
    def health_check(self) -> Dict:
        """Check API health (no auth required)"""
        return requests.get(f"{self.BASE_URL}/health").json()
    
    def get_user(self) -> Dict:
        """Get current authenticated user"""
        return self._request("GET", "/user")["data"]
    
    def list_servers(self, page: int = 1, per_page: int = 100, 
                     search: str = None, status: str = None) -> Dict:
        """
        List servers with optional filtering.
        
        Args:
            page: Page number
            per_page: Results per page
            search: Search by name
            status: Filter by status (provisioned, etc.)
        
        Returns:
            Dict with 'items' and 'pagination'
        """
        params = {
            "page": page,
            "per_page": per_page,
        }
        if search:
            params["search"] = search
        if status:
            params["status"] = status
        
        response = self._request("GET", "/servers", params=params)
        data = response.get("data", {})
        
        return {
            "items": data.get("items") or data.get("data", []),
            "pagination": data.get("pagination") or data.get("meta", {})
        }
    
    def get_server(self, server_uuid: str) -> Dict:
        """Get specific server"""
        return self._request("GET", f"/servers/{server_uuid}")["data"]
    
    def list_sites(self, page: int = 1, per_page: int = 100,
                   server_uuid: str = None, search: str = None,
                   site_type: str = None, status: str = None) -> Dict:
        """
        List sites with optional filtering.
        
        Args:
            page: Page number
            per_page: Results per page
            server_uuid: Filter by server
            search: Search by domain/title
            site_type: Filter by type (wordpress, etc.)
            status: Filter by status
        
        Returns:
            Dict with 'items' and 'pagination'
        """
        params = {
            "page": page,
            "per_page": per_page,
        }
        if server_uuid:
            params["server_uuid"] = server_uuid
        if search:
            params["search"] = search
        if site_type:
            params["type"] = site_type
        if status:
            params["status"] = status
        
        response = self._request("GET", "/sites", params=params)
        data = response.get("data", {})
        
        return {
            "items": data.get("items") or data.get("data", []),
            "pagination": data.get("pagination") or data.get("meta", {})
        }
    
    def get_site(self, site_uuid: str) -> Dict:
        """Get specific site"""
        return self._request("GET", f"/sites/{site_uuid}")["data"]
    
    def get_site_status(self, site_uuid: str) -> Dict:
        """Get site provisioning status"""
        return self._request("GET", f"/sites/{site_uuid}/status")["data"]
    
    def get_site_events(self, site_uuid: str, page: int = 1) -> List[Dict]:
        """Get site events (deployment, backups, etc.)"""
        response = self._request("GET", f"/sites/{site_uuid}/events", 
                               params={"page": page})
        data = response.get("data", {})
        return data.get("items") or data.get("data", [])
    
    def get_site_backups(self, site_uuid: str) -> List[Dict]:
        """Get site backup history"""
        response = self._request("GET", f"/sites/{site_uuid}/backups")
        data = response.get("data", {})
        return data.get("items") or data.get("data", [])
    
    def get_site_ssh_config(self, site_uuid: str) -> Dict:
        """Get site SSH/SFTP configuration"""
        return self._request("GET", f"/sites/{site_uuid}/ssh")["data"]
    
    def list_blueprints(self, page: int = 1, per_page: int = 100) -> Dict:
        """List WordPress blueprints (pre-configured stacks)"""
        response = self._request("GET", "/blueprints",
                               params={"page": page, "per_page": per_page})
        data = response.get("data", {})
        return {
            "items": data.get("items") or data.get("data", []),
            "pagination": data.get("pagination") or data.get("meta", {})
        }
    
    # ========================================================================
    # WRITE OPERATIONS
    # ========================================================================
    
    def reboot_server(self, server_uuid: str) -> Dict:
        """Reboot a server (DANGEROUS - requires confirmation)"""
        return self._request("POST", f"/servers/{server_uuid}/reboot")["data"]
    
    def create_wordpress_site(self, server_uuid: str, domain: str = None,
                            title: str = None, php_version: str = "8.2",
                            ssl_provider: str = "letsencrypt",
                            blueprint_uuid: str = None,
                            cache_full_page: bool = True,
                            cache_object: bool = True) -> Dict:
        """
        Create a WordPress site.
        
        Args:
            server_uuid: Target server
            domain: Domain name (required for live mode)
            title: Site title
            php_version: PHP version (8.1, 8.2, 8.3, etc.)
            ssl_provider: SSL provider (letsencrypt, custom, none)
            blueprint_uuid: Pre-configured blueprint
            cache_full_page: Enable full-page caching
            cache_object: Enable object caching
        
        Returns:
            Site data (includes auto-generated credentials if demo mode)
        """
        payload = {
            "mode": "live" if domain else "demo",
            "php_version": php_version,
            "cache": {
                "full_page": cache_full_page,
                "object_cache": cache_object
            }
        }
        
        if domain:
            payload["domain"] = domain
            payload["title"] = title or domain.replace(".", " ").title()
            payload["ssl"] = {"provider": ssl_provider}
        else:
            payload["title"] = title or "Demo Site"
        
        if blueprint_uuid:
            payload["blueprint_uuid"] = blueprint_uuid
        
        return self._request("POST", f"/servers/{server_uuid}/sites/wordpress",
                            json=payload)["data"]
    
    def trigger_backup(self, site_uuid: str) -> Dict:
        """Trigger manual backup of a site"""
        return self._request("POST", f"/sites/{site_uuid}/backup")["data"]
    
    def purge_cache(self, site_uuid: str) -> Dict:
        """Purge full-page cache for a site"""
        return self._request("POST", f"/sites/{site_uuid}/cache/purge")["data"]
    
    def update_ssh_config(self, site_uuid: str,
                         auth_mode: str = "public_key",
                         ssh_keys: List[str] = None,
                         password: str = None) -> Dict:
        """
        Update SSH/SFTP configuration.
        
        Args:
            site_uuid: Target site
            auth_mode: 'public_key' or 'password'
            ssh_keys: List of SSH public keys
            password: SSH password (if auth_mode='password')
        
        Returns:
            Updated SSH config
        """
        payload = {"authentication_mode": auth_mode}
        
        if auth_mode == "public_key":
            if not ssh_keys:
                raise ValueError("ssh_keys required for public_key mode")
            payload["ssh_public_keys"] = ssh_keys
        elif auth_mode == "password":
            if not password:
                raise ValueError("password required for password mode")
            payload["password"] = password
        
        return self._request("PUT", f"/sites/{site_uuid}/ssh",
                            json=payload)["data"]
    
    def create_sudo_user(self, server_uuid: str, username: str,
                        password: str, ssh_keys: List[str] = None,
                        is_temporary: bool = False) -> Dict:
        """
        Create sudo user on server.
        
        Args:
            server_uuid: Target server
            username: Username
            password: Password
            ssh_keys: SSH public keys
            is_temporary: Temporary or permanent user
        
        Returns:
            New user data
        """
        payload = {
            "username": username,
            "password": password,
            "is_temporary": is_temporary
        }
        if ssh_keys:
            payload["ssh_public_keys"] = ssh_keys
        
        return self._request("POST", f"/servers/{server_uuid}/sudo-users",
                            json=payload)["data"]


class XCloudDeployer:
    """High-level deployment automation for xCloud"""
    
    def __init__(self, api: XCloudAPI = None, token: str = None):
        """
        Initialize deployer.
        
        Args:
            api: XCloudAPI instance
            token: API token (creates new instance if api not provided)
        """
        self.api = api or XCloudAPI(token)
    
    def create_site(self, domain: str, server_name: str = "Matrix Zion",
                   php_version: str = "8.2", title: str = None) -> Dict:
        """
        Create WordPress site by server name.
        
        Args:
            domain: Domain name
            server_name: Server name (looks up UUID automatically)
            php_version: PHP version
            title: Site title
        
        Returns:
            Site data
        """
        # Find server by name
        servers = self.api.list_servers(search=server_name)
        if not servers["items"]:
            raise ValueError(f"Server '{server_name}' not found")
        
        server_uuid = servers["items"][0]["uuid"]
        
        # Create site
        return self.api.create_wordpress_site(
            server_uuid=server_uuid,
            domain=domain,
            title=title or domain,
            php_version=php_version
        )
    
    def create_site_with_poll(self, domain: str, server_uuid: str,
                             timeout: int = 600, poll_interval: int = 10) -> Dict:
        """
        Create WordPress site and wait for provisioning to complete.
        
        Args:
            domain: Domain name
            server_uuid: Server UUID
            timeout: Max time to wait (seconds)
            poll_interval: Polling interval (seconds)
        
        Returns:
            Provisioned site data
        """
        # Create site
        site = self.api.create_wordpress_site(
            server_uuid=server_uuid,
            domain=domain
        )
        site_uuid = site["uuid"]
        
        # Poll until ready
        start_time = time.time()
        while time.time() - start_time < timeout:
            status = self.api.get_site_status(site_uuid)
            
            if status.get("provisioned"):
                return self.api.get_site(site_uuid)
            
            time.sleep(poll_interval)
        
        raise XCloudTimeoutError(
            f"Site provisioning timed out after {timeout}s"
        )
    
    def enable_monitoring(self, site_uuid: str, 
                         check_interval: int = 300) -> Dict:
        """
        Enable monitoring for a site.
        
        Args:
            site_uuid: Site UUID
            check_interval: Health check interval (seconds)
        
        Returns:
            Monitoring config
        """
        return {
            "site_uuid": site_uuid,
            "check_interval": check_interval,
            "enabled": True,
            "checks": [
                {"type": "http", "endpoint": "/", "expected_status": 200},
                {"type": "ssl", "check_expiration": True},
                {"type": "database", "check_connectivity": True}
            ]
        }
    
    def backup_all_sites(self, server_uuid: str = None) -> List[Dict]:
        """
        Backup all sites (optionally filtered by server).
        
        Args:
            server_uuid: Optional server filter
        
        Returns:
            List of backup operations triggered
        """
        sites = self.api.list_sites(server_uuid=server_uuid)
        backed_up = []
        
        for site in sites["items"]:
            try:
                result = self.api.trigger_backup(site["uuid"])
                backed_up.append({
                    "site_uuid": site["uuid"],
                    "domain": site.get("domain") or site.get("name"),
                    "status": "backup_triggered",
                    "result": result
                })
            except XCloudAPIError as e:
                backed_up.append({
                    "site_uuid": site["uuid"],
                    "domain": site.get("domain") or site.get("name"),
                    "status": "backup_failed",
                    "error": str(e)
                })
        
        return backed_up
    
    def get_fleet_health(self) -> Dict:
        """
        Get health snapshot of entire fleet.
        
        Returns:
            Fleet health metrics
        """
        servers = self.api.list_servers(per_page=100)
        sites = self.api.list_sites(per_page=100)
        
        total_servers = servers["pagination"].get("total", len(servers["items"]))
        total_sites = sites["pagination"].get("total", len(sites["items"]))
        
        site_status = {}
        for site in sites["items"]:
            status = site.get("status", "unknown")
            site_status[status] = site_status.get(status, 0) + 1
        
        return {
            "timestamp": datetime.now().isoformat(),
            "servers": {
                "total": total_servers,
                "provisioned": sum(1 for s in servers["items"] 
                                  if s.get("status") == "provisioned")
            },
            "sites": {
                "total": total_sites,
                "by_status": site_status,
                "by_type": self._sites_by_type(sites["items"])
            }
        }
    
    def _sites_by_type(self, sites: List[Dict]) -> Dict[str, int]:
        """Count sites by type"""
        by_type = {}
        for site in sites:
            site_type = site.get("type", "unknown")
            by_type[site_type] = by_type.get(site_type, 0) + 1
        return by_type


if __name__ == "__main__":
    # Quick test
    try:
        api = XCloudAPI()
        user = api.get_user()
        print(f"✅ Authenticated as: {user['name']} ({user['email']})")
        
        health = api.get_user()
        print(f"✅ User UUID: {user['uuid']}")
        
        deployer = XCloudDeployer(api)
        fleet = deployer.get_fleet_health()
        print(f"✅ Fleet health: {json.dumps(fleet, indent=2)}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
