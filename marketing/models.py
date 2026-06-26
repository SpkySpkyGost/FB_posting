from django.db import models


class Post(models.Model):
    external_id = models.CharField(max_length=255, unique=True)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    native_id = models.CharField(max_length=255, null=True, blank=True)

    mode = models.CharField(max_length=50, default='Direct API')

    reactions = models.IntegerField(null=True, blank=True)
    comments = models.IntegerField(null=True, blank=True)
    shares = models.IntegerField(null=True, blank=True)
    engagement_total = models.IntegerField(null=True, blank=True)
    last_fetched_at = models.DateTimeField(null=True, blank=True)
    remote_updated_at = models.DateTimeField(null=True, blank=True)

    raw_response = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.external_id


class RequestLog(models.Model):
    timestamp = models.DateTimeField(auto_now_add=True)
    action = models.CharField(max_length=16)          # post / fetch
    mode = models.CharField(max_length=32)            # Direct / Orchestrated
    target = models.CharField(max_length=255, blank=True)
    success = models.BooleanField(default=False)
    raw_response = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        state = 'ok' if self.success else 'fail'
        return f'[{state}] {self.action} {self.timestamp:%H:%M:%S}'