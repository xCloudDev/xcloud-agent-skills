#!/usr/bin/env python3
"""
xCloud Async Operation Tracking
Provides reliable polling, state management, and retry logic for async xCloud operations.

Usage:
    poller = AsyncPoller(api, state_file="xcloud-state.json")
    
    # Wait for site provisioning
    site = poller.poll_until_ready(
        resource_type="site",
        uuid="...",
        timeout=600
    )
    
    # Track long-running operations
    task_id = "backup-20260422-001"
    poller.track_operation(task_id, status="started")
    # ... do work ...
    poller.track_operation(task_id, status="completed", result={...})
"""

import json
import time
import os
from typing import Dict, Any, Optional, Callable
from datetime import datetime, timedelta
import backoff  # pip install backoff


class StateManager:
    """Persistent state tracking for async operations"""
    
    def __init__(self, state_file: str = "xcloud-state.json"):
        """
        Initialize state manager.
        
        Args:
            state_file: Path to state file
        """
        self.state_file = state_file
        self.state = self._load_state()
    
    def _load_state(self) -> Dict[str, Any]:
        """Load state from disk"""
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file, "r") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return {}
        return {}
    
    def _save_state(self):
        """Save state to disk"""
        with open(self.state_file, "w") as f:
            json.dump(self.state, f, indent=2, default=str)
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get state value"""
        return self.state.get(key, default)
    
    def set(self, key: str, value: Any):
        """Set state value and persist"""
        self.state[key] = value
        self._save_state()
    
    def update(self, key: str, **kwargs):
        """Update nested state"""
        if key not in self.state:
            self.state[key] = {}
        self.state[key].update(kwargs)
        self._save_state()
    
    def delete(self, key: str):
        """Delete state value"""
        if key in self.state:
            del self.state[key]
            self._save_state()
    
    def clear(self):
        """Clear all state"""
        self.state = {}
        self._save_state()


class AsyncPoller:
    """Poll xCloud operations until completion"""
    
    def __init__(self, api, state_file: str = "xcloud-state.json"):
        """
        Initialize async poller.
        
        Args:
            api: XCloudAPI instance
            state_file: State persistence file
        """
        self.api = api
        self.state = StateManager(state_file)
    
    def poll_until_ready(self, resource_type: str, uuid: str,
                         timeout: int = 600, interval: int = 10,
                         ready_check: Callable[[Dict], bool] = None) -> Dict:
        """
        Poll resource until ready.
        
        Args:
            resource_type: "site" or "server"
            uuid: Resource UUID
            timeout: Max time to wait (seconds)
            interval: Poll interval (seconds)
            ready_check: Custom ready function (default: provisioned=True)
        
        Returns:
            Resource data when ready
        """
        start_time = time.time()
        
        # Default ready check
        if ready_check is None:
            if resource_type == "site":
                ready_check = lambda r: r.get("provisioned") == True
            elif resource_type == "server":
                ready_check = lambda r: r.get("status") == "provisioned"
            else:
                raise ValueError(f"Unknown resource type: {resource_type}")
        
        # Track in state
        operation_id = f"{resource_type}:{uuid}"
        self.state.update(operation_id, status="polling", started_at=datetime.now().isoformat())
        
        while time.time() - start_time < timeout:
            try:
                # Fetch current status
                if resource_type == "site":
                    resource = self.api.get_site_status(uuid)
                elif resource_type == "server":
                    resource = self.api.get_server(uuid)
                else:
                    raise ValueError(f"Unknown resource type: {resource_type}")
                
                # Check if ready
                if ready_check(resource):
                    self.state.update(operation_id, 
                                    status="ready",
                                    ready_at=datetime.now().isoformat())
                    return resource
                
                # Wait before next poll
                time.sleep(interval)
                
            except Exception as e:
                self.state.update(operation_id,
                                status="error",
                                error=str(e))
                raise
        
        # Timeout
        self.state.update(operation_id,
                        status="timeout",
                        timeout_seconds=timeout)
        
        raise TimeoutError(
            f"{resource_type} {uuid} did not become ready within {timeout}s"
        )
    
    def track_operation(self, operation_id: str, status: str,
                       **metadata) -> Dict:
        """
        Track operation status and metadata.
        
        Args:
            operation_id: Unique operation identifier
            status: Operation status (started, in_progress, completed, failed)
            **metadata: Additional data to store
        
        Returns:
            Operation record
        """
        record = {
            "operation_id": operation_id,
            "status": status,
            "timestamp": datetime.now().isoformat(),
            **metadata
        }
        
        self.state.update(operation_id, **record)
        return record
    
    def get_operation(self, operation_id: str) -> Optional[Dict]:
        """Get operation status"""
        return self.state.get(operation_id)
    
    def get_operations(self, status: str = None) -> Dict[str, Dict]:
        """Get all operations, optionally filtered by status"""
        operations = {}
        for key, value in self.state.state.items():
            if isinstance(value, dict):
                if status is None or value.get("status") == status:
                    operations[key] = value
        return operations
    
    def retry_with_backoff(self, func: Callable, *args,
                          max_retries: int = 3,
                          base_wait: int = 1,
                          max_wait: int = 60) -> Any:
        """
        Retry operation with exponential backoff.
        
        Args:
            func: Function to retry
            *args: Function arguments
            max_retries: Max retry attempts
            base_wait: Initial wait time (seconds)
            max_wait: Max wait time (seconds)
        
        Returns:
            Function result
        """
        @backoff.on_exception(
            backoff.expo,
            Exception,
            max_tries=max_retries,
            base=base_wait,
            max_value=max_wait
        )
        def _retry():
            return func(*args)
        
        return _retry()


class RateLimitManager:
    """Manage API rate limiting"""
    
    def __init__(self, rate_limit: int = 60, window: int = 60):
        """
        Initialize rate limit manager.
        
        Args:
            rate_limit: Requests per window
            window: Time window (seconds)
        """
        self.rate_limit = rate_limit
        self.window = window
        self.requests = []
    
    def wait_if_needed(self) -> float:
        """
        Wait if approaching rate limit.
        
        Returns:
            Actual wait time (0 if no wait needed)
        """
        now = time.time()
        
        # Clean old requests outside window
        self.requests = [t for t in self.requests if now - t < self.window]
        
        if len(self.requests) >= self.rate_limit:
            # Calculate wait time
            oldest = self.requests[0]
            wait_time = self.window - (now - oldest)
            
            if wait_time > 0:
                time.sleep(wait_time)
                return wait_time
        
        return 0
    
    def record_request(self):
        """Record API request"""
        self.requests.append(time.time())


class OperationBatcher:
    """Batch operations to optimize API calls"""
    
    def __init__(self, api, batch_size: int = 10):
        """
        Initialize operation batcher.
        
        Args:
            api: XCloudAPI instance
            batch_size: Operations per batch
        """
        self.api = api
        self.batch_size = batch_size
        self.queue = []
    
    def queue_operation(self, operation: Dict) -> str:
        """
        Queue operation for batching.
        
        Args:
            operation: Operation definition
        
        Returns:
            Operation ID
        """
        operation_id = f"op_{len(self.queue)}_{int(time.time())}"
        operation["id"] = operation_id
        self.queue.append(operation)
        return operation_id
    
    def execute_batch(self) -> Dict[str, Any]:
        """
        Execute batched operations.
        
        Returns:
            Results by operation ID
        """
        results = {}
        
        for i in range(0, len(self.queue), self.batch_size):
            batch = self.queue[i:i + self.batch_size]
            
            for op in batch:
                try:
                    result = self._execute_operation(op)
                    results[op["id"]] = {
                        "status": "success",
                        "result": result
                    }
                except Exception as e:
                    results[op["id"]] = {
                        "status": "failed",
                        "error": str(e)
                    }
        
        self.queue = []
        return results
    
    def _execute_operation(self, op: Dict) -> Any:
        """Execute single operation"""
        op_type = op.get("type")
        
        if op_type == "backup":
            return self.api.trigger_backup(op["site_uuid"])
        elif op_type == "create_site":
            return self.api.create_wordpress_site(
                server_uuid=op["server_uuid"],
                domain=op.get("domain"),
                php_version=op.get("php_version", "8.2")
            )
        elif op_type == "purge_cache":
            return self.api.purge_cache(op["site_uuid"])
        else:
            raise ValueError(f"Unknown operation type: {op_type}")


class DeploymentTracker:
    """Track multi-step deployments"""
    
    def __init__(self, deployment_id: str, state: StateManager = None):
        """
        Initialize deployment tracker.
        
        Args:
            deployment_id: Unique deployment ID
            state: Optional StateManager instance
        """
        self.deployment_id = deployment_id
        self.state = state or StateManager()
        self.steps = []
    
    def start_step(self, step_name: str) -> str:
        """
        Start deployment step.
        
        Args:
            step_name: Step description
        
        Returns:
            Step ID
        """
        step_id = f"{self.deployment_id}:step_{len(self.steps)}"
        
        self.state.update(step_id,
                         status="started",
                         name=step_name,
                         started_at=datetime.now().isoformat())
        
        self.steps.append(step_id)
        return step_id
    
    def complete_step(self, step_id: str, result: Any = None):
        """
        Mark step as complete.
        
        Args:
            step_id: Step ID
            result: Step result
        """
        self.state.update(step_id,
                         status="completed",
                         result=result,
                         completed_at=datetime.now().isoformat())
    
    def fail_step(self, step_id: str, error: str):
        """
        Mark step as failed.
        
        Args:
            step_id: Step ID
            error: Error message
        """
        self.state.update(step_id,
                         status="failed",
                         error=error,
                         failed_at=datetime.now().isoformat())
    
    def get_status(self) -> Dict[str, Any]:
        """Get deployment status"""
        steps = {}
        for step_id in self.steps:
            steps[step_id] = self.state.get(step_id, {})
        
        return {
            "deployment_id": self.deployment_id,
            "steps": steps,
            "completed": sum(1 for s in steps.values() if s.get("status") == "completed"),
            "failed": sum(1 for s in steps.values() if s.get("status") == "failed")
        }


if __name__ == "__main__":
    # Quick test
    print("✅ xCloud Async module loaded")
    
    # Test state manager
    state = StateManager("/tmp/xcloud-test-state.json")
    state.set("test_op", {"status": "started"})
    print(f"✅ State saved: {state.get('test_op')}")
    
    # Test rate limiter
    limiter = RateLimitManager()
    for i in range(5):
        limiter.record_request()
        wait = limiter.wait_if_needed()
        print(f"Request {i+1}: wait={wait:.2f}s")
