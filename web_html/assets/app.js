const $ = s => document.querySelector(s);
const $$ = s => Array.from(document.querySelectorAll(s));

function logoSrc() {
    const img = $(".brand img");
    if (!img) return;
    const test = new Image();
    test.onload = () => { img.src = "resources/logo.png"; };
    test.onerror = () => { img.src = img.getAttribute("data-fallback") || "logo.png"; };
    test.src = "resources/logo.png";
}

function initMobile() {
    const btn = $("#menuBtn");
    const panel = $("#mobilePanel");
    if (!btn || !panel) return;
    btn.addEventListener("click", () => {
        panel.style.display = panel.style.display === "block" ? "none" : "block";
    });
}

function setActiveNav() {
    const path = location.pathname.split("/").pop() || "index.html";
    $$(".nav a, .mobile-nav a").forEach(a => {
        const to = a.getAttribute("href");
        if ((path === "" && to === "index.html") || to === path) {
            a.classList.add("active");
        }
    });
}

function initCustomize() {
    const panel = $("#customizePanel");
    if (!panel) return;
    const sections = $$("[data-section]");
    const stateKey = "nv:view";
    const saved = JSON.parse(localStorage.getItem(stateKey) || "{}");
    sections.forEach(sec => {
        const id = sec.getAttribute("data-section");
        if (saved[id] === false) sec.classList.add("hidden");
    });
    panel.querySelectorAll("input[type=checkbox]").forEach(cb => {
        const id = cb.value;
        cb.checked = saved[id] !== false;
        cb.addEventListener("change", () => {
            const s = $(`[data-section='${id}']`);
            if (!s) return;
            if (cb.checked) {
                s.classList.remove("hidden");
                saved[id] = true;
            } else {
                s.classList.add("hidden");
                saved[id] = false;
            }
            localStorage.setItem(stateKey, JSON.stringify(saved));
        });
    });
}

function initProjectsFilter() {
    const bar = $("#filterBar");
    if (!bar) return;
    const chips = $$(".chip");
    let active = "all";
    chips.forEach(c => c.addEventListener("click", () => {
        chips.forEach(x => x.classList.remove("active"));
        c.classList.add("active");
        active = c.getAttribute("data-tag");
        if (projectRenderer) {
            projectRenderer.filterProjects(active);
        }
    }));
}

function initLikes() {
    const likes = $$(".like-btn");
    likes.forEach(btn => {
        const id = btn.getAttribute("data-id");
        const key = `nv:like:${id}`;
        let val = parseInt(localStorage.getItem(key) || "0");
        const num = btn.querySelector(".like-count");
        if (num) num.textContent = String(val);
        btn.addEventListener("click", () => {
            val++;
            localStorage.setItem(key, String(val));
            if (num) num.textContent = String(val);
            btn.classList.add("active");
        });
    });
}

function reveal() {
    const els = $$(".fade-up");
    els.forEach((el, i) => {
        setTimeout(() => {
            el.style.animationDelay = `${i * 40}ms`;
            el.classList.add("in");
        }, 20);
    });
}

class ProjectRenderer {
    constructor() {
        this.api = new GitHubAPI();
        this.projects = [];
        this.displayedProjects = [];
        this.currentPage = 1;
        this.projectsPerPage = 6;
        this.isLoading = false;
        this.hasMore = true;
    }

    async loadProjects() {
        if (this.isLoading) return;
        this.isLoading = true;
        this.showLoading();

        try {
            const repos = await this.api.fetchRepositories({
                page: 1,
                perPage: 50,
                sort: 'updated'
            });

            const filteredRepos = this.api.filterRepositories(repos, {
                excludeForks: true,
                requireDescription: false,
                excludeArchived: true
            });

            const projects = [];
            for (const repo of filteredRepos) {
                try {
                    const languages = await this.api.fetchLanguages(repo.name);
                    const project = this.api.mapRepositoryToProject(repo, languages);
                    projects.push(project);
                } catch (error) {
                    console.warn(`Failed to process repo ${repo.name}:`, error);
                    const project = this.api.mapRepositoryToProject(repo, {});
                    projects.push(project);
                }
            }

            this.projects = projects;
            this.displayProjects();
        } catch (error) {
            console.error('Failed to load projects:', error);
            this.showError('加载项目失败，请稍后重试');
        } finally {
            this.isLoading = false;
            this.hideLoading();
        }
    }

    displayProjects() {
        const container = $('.projects-grid');
        if (!container) return;

        const startIndex = (this.currentPage - 1) * this.projectsPerPage;
        const endIndex = startIndex + this.projectsPerPage;
        const projectsToShow = this.projects.slice(0, endIndex);

        container.innerHTML = '';
        
        projectsToShow.forEach((project, index) => {
            const isHidden = index >= this.projectsPerPage;
            const card = this.createProjectCard(project, isHidden);
            container.appendChild(card);
        });

        this.displayedProjects = projectsToShow;
        this.hasMore = endIndex < this.projects.length;
        this.updateLoadMoreButton();
        
        setTimeout(() => {
            reveal();
        }, 100);
    }

    createProjectCard(project, isHidden = false) {
        const article = document.createElement('article');
        article.className = `project-card fade-up${isHidden ? ' more hidden' : ''}`;
        article.setAttribute('data-tags', project.category);

        const badges = project.tags.map(tag => 
            `<span class="badge"><span class="badge-dot"></span> ${tag}</span>`
        ).join('');

        article.innerHTML = `
            <div class="project-body">
                <h3>${project.title}</h3>
                <p class="muted">${project.description}</p>
                <div class="project-meta">
                    ${badges}
                </div>
                <div class="actions" style="margin-top:10px">
                    <a class="btn btn-ghost" href="${project.url}" target="_blank">查看代码</a>
                    <a class="btn btn-primary" href="${project.url}" target="_blank">GitHub</a>
                </div>
            </div>
        `;

        return article;
    }

    loadMore() {
        if (this.isLoading || !this.hasMore) return;
        
        const hidden = $$('.project-card.more.hidden');
        hidden.forEach(el => el.classList.remove('hidden'));
        
        this.hasMore = false;
        this.updateLoadMoreButton();
    }

    updateLoadMoreButton() {
        const btn = $('#loadMore');
        if (!btn) return;
        
        if (this.hasMore) {
            btn.style.display = 'inline-block';
            btn.textContent = '加载更多';
            btn.disabled = false;
        } else {
            btn.style.display = 'none';
        }
    }

    showLoading() {
        const container = $('.projects-grid');
        if (!container) return;
        
        container.innerHTML = `
            <div class="loading-state" style="text-align: center; padding: 40px; grid-column: 1 / -1;">
                <div class="loading-spinner" style="margin: 0 auto 16px; width: 32px; height: 32px; border: 3px solid #f3f3f3; border-top: 3px solid #007bff; border-radius: 50%; animation: spin 1s linear infinite;"></div>
                <p class="muted">正在加载项目...</p>
            </div>
        `;
    }

    hideLoading() {
        const loading = $('.loading-state');
        if (loading) {
            loading.remove();
        }
    }

    showError(message) {
        const container = $('.projects-grid');
        if (!container) return;
        
        container.innerHTML = `
            <div class="error-state" style="text-align: center; padding: 40px; grid-column: 1 / -1;">
                <p style="color: #dc3545; margin-bottom: 16px;">${message}</p>
                <button class="btn btn-primary" onclick="projectRenderer.loadProjects()">重新加载</button>
            </div>
        `;
    }

    filterProjects(tag) {
        const cards = $$('.project-card');
        cards.forEach(card => {
            const tags = card.getAttribute('data-tags') || '';
            if (tag === 'all' || tags.includes(tag)) {
                card.classList.remove('hidden');
            } else {
                card.classList.add('hidden');
            }
        });
    }
}

let projectRenderer;

function initLoadMore() {
    const btn = $("#loadMore");
    if (!btn) return;
    btn.addEventListener("click", () => {
        if (projectRenderer) {
            projectRenderer.loadMore();
        }
    });
}

function initCopyEmail() {
    const btn = $("#copyEmail");
    if (!btn) return;
    const email = btn.getAttribute("data-email") || "hello@yourmail.com";
    btn.addEventListener("click", () => {
        try {
            const ta = document.createElement("textarea");
            ta.value = email;
            ta.style.position = "fixed";
            ta.style.opacity = "0";
            document.body.appendChild(ta);
            ta.select();
            document.execCommand("copy");
            document.body.removeChild(ta);
            const old = btn.textContent;
            btn.textContent = "已复制";
            setTimeout(() => {
                btn.textContent = old;
            }, 1200);
        } catch (e) {}
    });
}

async function initProjects() {
    if (window.location.pathname.includes('projects.html')) {
        projectRenderer = new ProjectRenderer();
        await projectRenderer.loadProjects();
    }
}

function init() {
    logoSrc();
    initMobile();
    setActiveNav();
    initCustomize();
    initProjectsFilter();
    initLoadMore();
    initLikes();
    initCopyEmail();
    reveal();
    initProjects();
}

document.addEventListener("DOMContentLoaded", init);