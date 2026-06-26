from django.shortcuts import render, redirect
from django.urls import reverse
from django.core.paginator import Paginator
from django.utils import timezone
from .models import Post, RequestLog
from .services import get_marketing_service, MarketingServiceException


def dashboard(request):
    mode = request.POST.get('mode', request.session.get('last_mode', 'Direct API'))
    context = {'execution_mode': mode}

    if request.method == 'POST':
        action = request.POST.get('action')
        current_page = request.POST.get('page', 1)
        request.session['last_mode'] = mode
        flash_data = {}

        # ── 1. Publish Post ──────────────────────────────────────────────
        if action == 'post':
            message = request.POST.get('message')
            try:
                service = get_marketing_service(mode)
                ext_id, raw_data = service.publish_post(message)

                flash_data['post_id'] = ext_id
                flash_data['post_timestamp'] = timezone.localtime().strftime("%Y-%m-%d %H:%M:%S")
                flash_data['success_msg'] = f"Content successfully published via {mode}!"

                Post.objects.get_or_create(
                    external_id=ext_id,
                    defaults={'message': message, 'mode': mode}
                )
                RequestLog.objects.create(action='post', mode=mode, target=ext_id, success=True, raw_response=raw_data)
            except MarketingServiceException as e:
                flash_data['error_msg'] = f"Failed to post: {str(e)}"
                RequestLog.objects.create(action='post', mode=mode, target="Unknown", success=False,
                                          raw_response={'error': str(e)})

        # ── 2. Fetch Metrics ────────────────────────────────────────
        elif action == 'fetch':
            post_id = request.POST.get('post_id')
            db_post = Post.objects.filter(external_id=post_id).first()
            fetch_mode = db_post.mode if db_post else mode

            try:
                service = get_marketing_service(fetch_mode)
                metrics, raw_data = service.fetch_metrics(post_id)

                Post.objects.filter(external_id=post_id).update(
                    reactions=metrics['reactions'],
                    comments=metrics['comments'],
                    shares=metrics['shares'],
                    engagement_total=metrics['engagement_total'],
                    remote_updated_at=metrics.get('metricsUpdatedAt'),
                    last_fetched_at=timezone.now(),
                    raw_response=raw_data,

                )
                flash_data['success_msg'] = f"Metrics updated via {fetch_mode}!"
                RequestLog.objects.create(action='fetch', mode=fetch_mode, target=post_id, success=True,
                                          raw_response=raw_data)
            except MarketingServiceException as e:
                flash_data['error_msg'] = f"Failed to update metrics: {str(e)}."
                RequestLog.objects.create(action='fetch', mode=fetch_mode, target=post_id, success=False,
                                          raw_response={'error': str(e)})

        # Store flash data
        request.session['flash_data'] = flash_data

        # Safely build the redirect URL, preserving the pagination state
        try:
            redirect_url = reverse('dashboard')
        except:
            # Fallback in case your urls.py path isn't named 'dashboard'
            redirect_url = request.path

        return redirect(f"{redirect_url}?page={current_page}")

    # --- GET Request Handling ---
    flash = request.session.pop('flash_data', {})
    context.update(flash)

    # ── Pagination and Logs ─────────────────────────────────────
    post_list = Post.objects.all()
    paginator = Paginator(post_list, 10)
    page_number = request.GET.get('page', 1)

    context['posts'] = paginator.get_page(page_number)
    context['logs'] = RequestLog.objects.all()[:20]
    return render(request, 'marketing/dashboard.html', context)