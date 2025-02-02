include("../utils.jl")

@testset "Stiefel" begin
    @testset "Real" begin
        M = Stiefel(3, 2)
        M2 = MetricManifold(M, EuclideanMetric())
        @testset "Basics" begin
            @test repr(M) == "Stiefel(3, 2, ℝ)"
            x = [1.0 0.0; 0.0 1.0; 0.0 0.0]
            @test is_default_metric(M, EuclideanMetric())
            @test representation_size(M) == (3, 2)
            @test manifold_dimension(M) == 3
            base_manifold(M) === M
            @test_throws ManifoldDomainError is_point(M, [1.0, 0.0, 0.0, 0.0], true)
            @test_throws ManifoldDomainError is_point(
                M,
                1im * [1.0 0.0; 0.0 1.0; 0.0 0.0],
                true,
            )
            @test !is_vector(M, x, [0.0, 0.0, 1.0, 0.0])
            @test_throws ManifoldDomainError is_vector(
                M,
                x,
                1 * im * zero_vector(M, x),
                true,
            )
            @test default_retraction_method(M) === PolarRetraction()
            @test default_inverse_retraction_method(M) === PolarInverseRetraction()
            vtm = DifferentiatedRetractionVectorTransport(PolarRetraction())
            @test default_vector_transport_method(M) === vtm
        end
        @testset "Embedding and Projection" begin
            x = [1.0 0.0; 0.0 1.0; 0.0 0.0]
            y = similar(x)
            z = embed(M, x)
            @test z == x
            embed!(M, y, x)
            @test y == z
            a = [1.0 0.0; 0.0 2.0; 0.0 0.0]
            @test !is_point(M, a)
            b = similar(a)
            c = project(M, a)
            @test c == x
            project!(M, b, a)
            @test b == x
            X = [0.0 0.0; 0.0 0.0; -1.0 1.0]
            Y = similar(X)
            Z = embed(M, x, X)
            embed!(M, Y, x, X)
            @test Y == X
            @test Z == X
        end

        types = [Matrix{Float64}]
        TEST_FLOAT32 && push!(types, Matrix{Float32})
        TEST_STATIC_SIZED && push!(types, MMatrix{3,2,Float64,6})

        @testset "Stiefel(2, 1) special case" begin
            M21 = Stiefel(2, 1)
            w = inverse_retract(
                M21,
                SMatrix{2,1}([0.0, 1.0]),
                SMatrix{2,1}([sqrt(2), sqrt(2)]),
                QRInverseRetraction(),
            )
            @test isapprox(M21, w, SMatrix{2,1}([1.0, 0.0]))
        end

        @testset "inverse QR retraction cases" begin
            M43 = Stiefel(4, 3)
            p = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0; 0.0 0.0 0.0]
            Xinit = [0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0; 1.0 1.0 1.0]
            q = retract(M43, p, Xinit, QRRetraction())
            X1 = inverse_retract(
                M43,
                SMatrix{4,3}(p),
                SMatrix{4,3}(q),
                QRInverseRetraction(),
            )
            X2 = inverse_retract(M43, p, q, QRInverseRetraction())
            @test isapprox(M43, p, X1, X2)
            @test isapprox(M43, p, X1, Xinit)

            p2 = [1.0 0.0; 0.0 1.0; 0.0 0.0]
            q2 = exp(M, p2, [0.0 0.0; 0.0 0.0; 1.0 1.0])

            X1 = inverse_retract(
                M,
                SMatrix{3,2}(p2),
                SMatrix{3,2}(q2),
                QRInverseRetraction(),
            )
            X2 = inverse_retract(M, p2, q2, QRInverseRetraction())
            @test isapprox(M43, p2, X1, X2)
        end

        @testset "Type $T" for T in types
            x = [1.0 0.0; 0.0 1.0; 0.0 0.0]
            y = exp(M, x, [0.0 0.0; 0.0 0.0; 1.0 1.0])
            z = exp(M, x, [0.0 0.0; 0.0 0.0; -1.0 1.0])
            @test_throws MethodError distance(M, x, y)
            @test isapprox(
                M,
                retract(
                    M,
                    SMatrix{3,2}(x),
                    SA[0.0 0.0; 0.0 0.0; -1.0 1.0],
                    PolarRetraction(),
                ),
                retract(M, x, [0.0 0.0; 0.0 0.0; -1.0 1.0], PolarRetraction()),
                atol=1e-15,
            )
            pts = convert.(T, [x, y, z])
            v = inverse_retract(M, x, y, PolarInverseRetraction())
            @test !is_point(M, 2 * x)
            @test_throws DomainError !is_point(M, 2 * x, true)
            @test !is_vector(M, 2 * x, v)
            @test_throws ManifoldDomainError !is_vector(M, 2 * x, v, true)
            @test !is_vector(M, x, y)
            @test_throws DomainError is_vector(M, x, y, true)
            test_manifold(
                M,
                pts,
                basis_types_to_from=(DefaultOrthonormalBasis(),),
                basis_types_vecs=(DefaultOrthonormalBasis(),),
                test_exp_log=false,
                default_inverse_retraction_method=PolarInverseRetraction(),
                test_injectivity_radius=false,
                test_is_tangent=true,
                test_project_tangent=true,
                test_default_vector_transport=false,
                point_distributions=[Manifolds.uniform_distribution(M, pts[1])],
                test_vee_hat=false,
                projection_atol_multiplier=100.0,
                retraction_atol_multiplier=10.0,
                is_tangent_atol_multiplier=4 * 10.0^2,
                retraction_methods=[
                    PolarRetraction(),
                    QRRetraction(),
                    CayleyRetraction(),
                    PadeRetraction(2),
                    ProjectionRetraction(),
                ],
                inverse_retraction_methods=[
                    PolarInverseRetraction(),
                    QRInverseRetraction(),
                    ProjectionInverseRetraction(),
                ],
                vector_transport_methods=[
                    DifferentiatedRetractionVectorTransport(PolarRetraction()),
                    DifferentiatedRetractionVectorTransport(QRRetraction()),
                    ProjectionTransport(),
                ],
                vector_transport_retractions=[
                    PolarRetraction(),
                    QRRetraction(),
                    PolarRetraction(),
                ],
                vector_transport_inverse_retractions=[
                    PolarInverseRetraction(),
                    QRInverseRetraction(),
                    PolarInverseRetraction(),
                ],
                test_vector_transport_direction=[true, true, false],
                mid_point12=nothing,
                test_inplace=true,
                test_rand_point=true,
                test_rand_tvector=true,
            )

            @testset "inner/norm" begin
                v1 = inverse_retract(M, pts[1], pts[2], PolarInverseRetraction())
                v2 = inverse_retract(M, pts[1], pts[3], PolarInverseRetraction())

                @test real(inner(M, pts[1], v1, v2)) ≈ real(inner(M, pts[1], v2, v1))
                @test imag(inner(M, pts[1], v1, v2)) ≈ -imag(inner(M, pts[1], v2, v1))
                @test imag(inner(M, pts[1], v1, v1)) ≈ 0

                @test norm(M, pts[1], v1) isa Real
                @test norm(M, pts[1], v1) ≈ sqrt(inner(M, pts[1], v1, v1))
            end
        end

        @testset "Distribution tests" begin
            usd_mmatrix = Manifolds.uniform_distribution(M, @MMatrix [
                1.0 0.0
                0.0 1.0
                0.0 0.0
            ])
            @test isa(rand(usd_mmatrix), MMatrix)
        end
    end

    @testset "Complex" begin
        M = Stiefel(3, 2, ℂ)
        @testset "Basics" begin
            @test repr(M) == "Stiefel(3, 2, ℂ)"
            @test representation_size(M) == (3, 2)
            @test manifold_dimension(M) == 8
            @test Manifolds.allocation_promotion_function(M, exp!, (1,)) == complex
            @test !is_point(M, [1.0, 0.0, 0.0, 0.0])
            @test !is_vector(M, [1.0 0.0; 0.0 1.0; 0.0 0.0], [0.0, 0.0, 1.0, 0.0])
            x = [1.0 0.0; 0.0 1.0; 0.0 0.0]
        end
        types = [Matrix{ComplexF64}]
        @testset "Type $T" for T in types
            x = [0.5+0.5im 0.5+0.5im; 0.5+0.5im -0.5-0.5im; 0.0 0.0]
            y = exp(M, x, [0.0 0.0; 0.0 0.0; 1.0 1.0])
            z = exp(M, x, [0.0 0.0; 0.0 0.0; -1.0 1.0])
            pts = convert.(T, [x, y, z])
            v = inverse_retract(M, x, y, PolarInverseRetraction())
            @test !is_point(M, 2 * x)
            @test_throws DomainError !is_point(M, 2 * x, true)
            @test !is_vector(M, 2 * x, v)
            @test_throws ManifoldDomainError !is_vector(M, 2 * x, v, true)
            @test !is_vector(M, x, y)
            @test_throws DomainError is_vector(M, x, y, true)
            test_manifold(
                M,
                pts,
                test_exp_log=false,
                default_inverse_retraction_method=PolarInverseRetraction(),
                test_injectivity_radius=false,
                test_is_tangent=true,
                test_project_tangent=true,
                test_default_vector_transport=false,
                test_vee_hat=false,
                projection_atol_multiplier=100.0,
                retraction_atol_multiplier=10.0,
                is_tangent_atol_multiplier=4 * 10.0^2,
                retraction_methods=[PolarRetraction(), QRRetraction()],
                inverse_retraction_methods=[
                    PolarInverseRetraction(),
                    QRInverseRetraction(),
                ],
                vector_transport_methods=[
                    DifferentiatedRetractionVectorTransport(PolarRetraction()),
                    DifferentiatedRetractionVectorTransport(QRRetraction()),
                    ProjectionTransport(),
                ],
                vector_transport_retractions=[
                    PolarRetraction(),
                    QRRetraction(),
                    PolarRetraction(),
                ],
                vector_transport_inverse_retractions=[
                    PolarInverseRetraction(),
                    QRInverseRetraction(),
                    PolarInverseRetraction(),
                ],
                test_vector_transport_direction=[true, true, false],
                mid_point12=nothing,
                test_inplace=true,
                test_rand_point=true,
            )

            @testset "inner/norm" begin
                v1 = inverse_retract(M, pts[1], pts[2], PolarInverseRetraction())
                v2 = inverse_retract(M, pts[1], pts[3], PolarInverseRetraction())

                @test real(inner(M, pts[1], v1, v2)) ≈ real(inner(M, pts[1], v2, v1))
                @test imag(inner(M, pts[1], v1, v2)) ≈ -imag(inner(M, pts[1], v2, v1))
                @test imag(inner(M, pts[1], v1, v1)) ≈ 0

                @test norm(M, pts[1], v1) isa Real
                @test norm(M, pts[1], v1) ≈ sqrt(inner(M, pts[1], v1, v1))
            end
        end
    end

    @testset "Quaternion" begin
        M = Stiefel(3, 2, ℍ)
        @testset "Basics" begin
            @test representation_size(M) == (3, 2)
            @test manifold_dimension(M) == 18
        end
    end

    @testset "Padé & Caley retractions and Caley based transport" begin
        M = Stiefel(3, 2)
        p = [1.0 0.0; 0.0 1.0; 0.0 0.0]
        X = [0.0 0.0; 0.0 0.0; 1.0 1.0]
        r1 = CayleyRetraction()
        @test r1 == PadeRetraction(1)
        @test repr(r1) == "CayleyRetraction()"
        q1 = retract(M, p, X, r1)
        @test is_point(M, q1)
        Y = vector_transport_direction(
            M,
            p,
            X,
            X,
            DifferentiatedRetractionVectorTransport(CayleyRetraction()),
        )
        @test is_vector(M, q1, Y; atol=10^-15)
        Y2 = vector_transport_direction(
            M,
            p,
            X,
            X,
            DifferentiatedRetractionVectorTransport(CayleyRetraction()),
        )
        @test is_vector(M, q1, Y2; atol=10^-15)
        r2 = PadeRetraction(2)
        @test repr(r2) == "PadeRetraction(2)"
        q2 = retract(M, p, X, r2)
        @test is_point(M, q2)
    end

    @testset "Canonical Metric" begin
        M3 = MetricManifold(Stiefel(3, 2), CanonicalMetric())
        p = [1.0 0.0; 0.0 1.0; 0.0 0.0]
        X = [0.0 0.0; 0.0 0.0; 1.0 1.0]
        q = exp(M3, p, X)
        Y = [0.0 0.0; 0.0 0.0; -1.0 1.0]
        r = exp(M3, p, Y)
        @test isapprox(M3, p, log(M3, p, q), X)
        @test isapprox(M3, p, log(M3, p, r), Y)
        @test inner(M3, p, X, Y) == 0
        @test inner(M3, p, X, 2 * X + 3 * Y) == 2 * inner(M3, p, X, X)
        @test norm(M3, p, X) ≈ distance(M3, p, q)
        # check on a higher dimensional manifold, that the iterations are actually used
        M4 = MetricManifold(Stiefel(10, 2), CanonicalMetric())
        p = Matrix{Float64}(I, 10, 2)
        Random.seed!(42)
        Z = project(base_manifold(M4), p, 0.2 .* randn(size(p)))
        s = exp(M4, p, Z)
        Z2 = log(M4, p, s)
        @test isapprox(M4, p, Z, Z2)
        Z3 = similar(Z2)
        log!(M4, Z3, p, s)
        @test isapprox(M4, p, Z2, Z3)

        M4 = MetricManifold(Stiefel(3, 3), CanonicalMetric())
        p = project(M4, randn(3, 3))
        X = project(M4, p, randn(3, 3))
        Y = project(M4, p, randn(3, 3))
        @test inner(M4, p, X, Y) ≈ tr(X' * (I - p * p' / 2) * Y)
    end

    @testset "StiefelSubmersionMetric" begin
        @testset "StiefelFactorization" begin
            n = 6
            @testset for k in [2, 3]
                M = MetricManifold(Stiefel(n, k), StiefelSubmersionMetric(rand()))
                p = project(M, randn(representation_size(M)))
                X = project(M, p, randn(representation_size(M)))
                X /= norm(M, p, X)
                q = exp(M, p, X)
                qfact = Manifolds.stiefel_factorization(p, q)
                @testset "basic properties" begin
                    @test qfact isa Manifolds.StiefelFactorization
                    @test qfact.U[1:n, 1:k] ≈ p
                    @test qfact.U'qfact.U ≈ I
                    @test qfact.U * qfact.Z ≈ q
                    @test is_point(Stiefel(2k, k), qfact.Z)

                    Xfact = Manifolds.stiefel_factorization(p, X)
                    @test Xfact isa Manifolds.StiefelFactorization
                    @test Xfact.U[1:n, 1:k] ≈ p
                    @test Xfact.U'Xfact.U ≈ I
                    @test Xfact.U * Xfact.Z ≈ X
                    @test is_vector(Rotations(k), I(k), Xfact.Z[1:k, 1:k])

                    pfact2 = Manifolds.stiefel_factorization(p, p)
                    @test pfact2 isa Manifolds.StiefelFactorization
                    @test pfact2.U[1:n, 1:k] ≈ p
                    @test pfact2.U'pfact2.U ≈ I
                    @test pfact2.Z ≈ [I(k); zeros(k, k)] atol = 1e-6
                end
                @testset "basic functions" begin
                    @test size(qfact) == (n, k)
                    @test eltype(qfact) === eltype(q)
                end
                @testset "similar" begin
                    qfact2 = similar(qfact)
                    @test qfact2.U === qfact.U
                    @test size(qfact2.Z) == size(qfact.Z)
                    @test eltype(qfact2.Z) === eltype(qfact.Z)

                    qfact3 = similar(qfact, Float32)
                    @test eltype(qfact3) === Float32
                    @test eltype(qfact3.U) === Float32
                    @test eltype(qfact3.Z) === Float32
                    @test qfact3.U ≈ qfact.U
                    @test size(qfact3.Z) == size(qfact.Z)

                    qfact4 = similar(qfact, Float32, (n, k))
                    @test eltype(qfact4) === Float32
                    @test eltype(qfact4.U) === Float32
                    @test eltype(qfact4.Z) === Float32
                    @test qfact4.U ≈ qfact.U
                    @test size(qfact4.Z) == size(qfact.Z)

                    @test_throws Exception similar(qfact, Float32, (n, k + 1))
                end
                @testset "copyto!" begin
                    qfact2 = similar(qfact)
                    copyto!(qfact2, qfact)
                    @test qfact2.U === qfact.U
                    @test qfact2.Z ≈ qfact.Z

                    q2 = similar(q)
                    copyto!(q2, qfact)
                    @test q2 ≈ q

                    qfact3 = similar(qfact)
                    copyto!(qfact3, q)
                    @test qfact3.U === qfact.U
                    @test qfact3.Z ≈ qfact.Z
                end
                @testset "dot" begin
                    Afact = similar(qfact)
                    Afact.Z .= randn.()
                    A = copyto!(similar(q), Afact)
                    Bfact = similar(qfact)
                    Bfact.Z .= randn.()
                    B = copyto!(similar(q), Bfact)
                    @test dot(Afact, Bfact) ≈ dot(A, B)
                end
                @testset "broadcast!" begin
                    rfact = similar(qfact)
                    @testset for f in [*, +, -]
                        rfact .= f.(qfact, 2.5)
                        @test rfact.U === qfact.U
                        @test rfact.Z ≈ f.(qfact.Z, 2.5)
                    end
                end
                @testset "project" begin
                    rfact = similar(qfact)
                    rfact.Z .= randn.()
                    r = copyto!(similar(q), rfact)
                    rfactproj = project(M, rfact)
                    @test rfactproj isa Manifolds.StiefelFactorization
                    @test copyto!(similar(r), rfactproj) ≈ project(M, r)

                    Yfact = similar(qfact)
                    Yfact.Z .= randn.()
                    Y = copyto!(similar(q), Yfact)
                    Yfactproj = project(M, rfact, Yfact)
                    @test Yfactproj isa Manifolds.StiefelFactorization
                    @test copyto!(similar(Y), Yfactproj) ≈ project(M, r, Y)
                end
                @testset "inner" begin
                    rfact = similar(qfact)
                    rfact.Z .= randn.()
                    rfact = project(M, rfact)

                    Yfact = similar(qfact)
                    Yfact.Z .= randn.()
                    Yfact = project(M, rfact, Yfact)

                    Zfact = similar(qfact)
                    Zfact.Z .= randn.()
                    Zfact = project(M, rfact, Zfact)

                    r, Z, Y = map(x -> copyto!(similar(q), x), (rfact, Zfact, Yfact))
                    @test inner(M, rfact, Yfact, Zfact) ≈ inner(M, r, Y, Z)
                end
                @testset "exp" begin
                    pfact = copyto!(similar(qfact), p)
                    Xfact = copyto!(similar(qfact), X)
                    rfact = exp(M, pfact, Xfact)
                    r = exp(M, p, X)
                    @test rfact isa Manifolds.StiefelFactorization
                    @test copyto!(similar(r), rfact) ≈ r
                end
            end
        end

        @testset "expm_frechet" begin
            n = 50
            for ft in (1e-2, 0.19, 0.78, 1.7, 4.5, 9.0)
                A = rand(n, n)

                A = A / maximum(sum(abs.(A), dims=1)) * ft
                E = rand(n, n)
                E = E / norm(E, 2) * ft
                buff = Array{Float64,2}(undef, 16 * n, n)
                ret = Manifolds._diff_pade3(A, E)
                Manifolds._diff_pade3!(buff, A, E)
                @test maximum(abs.(ret[1] - buff[1:n, 1:end])) < 1e-6
                @views begin
                    expA = buff[1:n, :]
                    expAE = buff[(n + 1):(2 * n), :]
                end
                Manifolds.expm_frechet!(buff, A, E)
                expA1, expAE1 = Manifolds.expm_frechet(A, E)
                @test maximum(abs.((expA - expA1))) < 1e-9
                @test maximum(abs.((expAE - expAE1))) < 1e-9
                dlt = 1e-7
                @test maximum(abs.((exp(A + dlt * E) .- exp(A)) / dlt .- expAE)) /
                      norm(expA1, 2) < 1e-3
            end
        end

        @testset "lbfgs" begin
            p = 100
            function rosenbrock!(f, df, x)
                D = size(x)[1]
                f = sum(
                    100 * (x[2:end] .- x[1:(end - 1)] .^ 2) .^ 2 .+
                    (1 .- x[1:(end - 1)]) .^ 2,
                )

                @views begin
                    xm = x[2:(end - 1)]
                    xm_m1 = x[1:(end - 2)]
                    xm_p1 = x[3:end]
                end
                df[2:(end - 1)] .= (
                    200 * (xm - xm_m1 .^ 2) - 400 * (xm_p1 - xm .^ 2) .* xm - 2 * (1 .- xm)
                )
                df[1] = -400 * x[1] * (x[2] - x[1]^2) - 2 * (1 - x[1])
                df[end] = 200 * (x[end] - x[end - 1]^2)
                return f
            end
            x0 = randn(p)

            function pcondR(y)
                x = fill!(similar(y), 1)
                ret = similar(x)
                ret[1] = (1200 * x[1]^2 - 400 * x[2] + 2)
                ret[2:(end - 1)] .= 202 .+ 1200 * x[2:(end - 1)] .^ 2 .- 400 * x[3:end]
                ret[end] = 200
                return 1.0 / ret
            end

            # test to show different scenarios of the optimizer are reached.
            x0 .= 0.0
            x, f, exitflag, output = Manifolds.minimize(
                rosenbrock!,
                x0,
                precond=pcondR,
                max_itr=2,
                max_fun_evals=3,
            )
            @test exitflag == 0 &&
                  output["message"] == "Reached Maximum Number of Function Evaluations"

            x0 .= 0.0
            x, f, exitflag, output = Manifolds.minimize(
                rosenbrock!,
                x0,
                precond=pcondR,
                max_itr=2,
                max_fun_evals=30,
            )
            @test exitflag == 0 &&
                  output["message"] == "Reached Maximum Number of Iterations"

            x0 .= 0.0
            x, f, exitflag, output = Manifolds.minimize(
                rosenbrock!,
                x0,
                precond=pcondR,
                func_tol=1e-3,
                max_itr=1000,
                max_fun_evals=1300,
            )
            @test exitflag == 2

            x0 .= 0.0
            x, f, exitflag, output = Manifolds.minimize(
                rosenbrock!,
                x0,
                precond=pcondR,
                grad_tol=1e-3,
                max_itr=1000,
                max_fun_evals=1300,
            )
            @test exitflag == 1

            x, f, exitflag, output = Manifolds.minimize(
                rosenbrock!,
                x0,
                precond=pcondR,
                max_itr=1000,
                max_fun_evals=1300,
            )
            @test exitflag > 0

            # if initial point is optimal
            x1, f1, exitflag1, output1 = Manifolds.minimize(
                rosenbrock!,
                x,
                max_itr=1000,
                max_fun_evals=1300,
                grad_tol=1e-3,
                max_ls=2,
            )

            x1, f1, exitflag1, output1 =
                Manifolds.minimize(rosenbrock!, x0, max_itr=1000, max_fun_evals=1300)
            @test exitflag > 0

            x1, f1, exitflag1, output1 = Manifolds.minimize(
                rosenbrock!,
                x0,
                max_itr=1000,
                max_fun_evals=1300,
                max_ls=3,
            )

            x1, f1, exitflag1, output1 = Manifolds.minimize(
                rosenbrock!,
                x0,
                max_itr=1000,
                max_fun_evals=1300,
                func_tol=1e-2,
                max_ls=2,
            )

            function bad_func!(f, df, x)
                f = (sum(x .* x))^(1 / 3)
                df[:] = 2 / 3 * x ./ (f * f)
                return f
            end
            x0[:] .= 0.0
            x1, f1, exitflag1, output1 = Manifolds.minimize(bad_func!, x0)

            function randpoint(M)
                return project(M, randn(representation_size(M)))
            end

            # generate unit vector            
            function randvec(M, p)
                X = project(M, p, randn(representation_size(M)))
                X ./= sqrt(inner(M, p, X, X))
                return X
            end

            # run a lot of scenarios - this will hit most
            # conditions in the optimizer.
            Random.seed!(0)

            n_samples = 3
            Random.seed!(0)
            max_ft = 0.5
            NN = 50
            pretol = 1e-3

            for i in 1:NN
                n = Int(ceil(2^(7 / 1.04 * (0.04 + rand()))))
                if n < 4
                    n = 4
                end

                k = rand(2:(n - 1))
                α = 3 * rand() - 0.9
                M = MetricManifold(Stiefel(n, k), StiefelSubmersionMetric(α))
                p = randpoint(M)
                X = randvec(M, p)

                ft = (rand() + 0.1) * max_ft / 0.2
                q = exp(M, p, ft * pi * X)
                println("i=\t", i, " n=\t", n, " k=\t", k)

                try
                    XF = Manifolds.log_lbfgs(
                        M,
                        p,
                        q,
                        tolerance=1e-8,
                        max_itr=1000,
                        pretol=pretol,
                    )
                catch
                    println("bad at i=\t", i)
                end
            end
        end

        g = StiefelSubmersionMetric(1)
        @test g isa StiefelSubmersionMetric{Int}

        @testset "dot_exp" begin
            for M in [Stiefel(3, 3), Stiefel(4, 3), Stiefel(4, 2)]
                for α in [-0.75, -0.25, 0.5]
                    MM = MetricManifold(M, StiefelSubmersionMetric(α))
                    p = project(MM, randn(representation_size(M)))
                    X = project(MM, p, randn(representation_size(M)))
                    X ./= norm(MM, p, X)

                    t = 1.3
                    q = exp(MM, p, t * X)
                    qx = similar(q)
                    dqx = similar(q)

                    dot_exp!(MM, qx, dqx, p, X, t)
                    qx1, dqx1 = dot_exp(MM, p, X, t)

                    @test isapprox(MM, qx, q)
                    @test isapprox(MM, qx, dqx, dqx1)
                    dlt = 1e-7
                    qxp = exp(MM, p, (t + dlt) * X)
                    qxm = exp(MM, p, (t - dlt) * X)
                    qdt = (qxp - qxm) / dlt / 2
                    @test maximum(abs.(qdt .- dqx)) < 1e-4
                end
            end
        end

        @testset for M in [Stiefel(3, 3), Stiefel(4, 3), Stiefel(4, 2)]
            Mcan = MetricManifold(M, CanonicalMetric())
            Meu = MetricManifold(M, EuclideanMetric())
            @testset "α=$α" for (α, Mcomp) in [(0, Mcan), (-1 // 2, Meu)]
                p = project(M, randn(representation_size(M)))
                X = project(M, p, randn(representation_size(M)))
                X ./= norm(Mcomp, p, X)
                Y = project(M, p, randn(representation_size(M)))
                MM = MetricManifold(M, StiefelSubmersionMetric(α))
                @test inner(MM, p, X, Y) ≈ inner(Mcomp, p, X, Y)
                q = exp(Mcomp, p, X)
                @test isapprox(MM, q, exp(Mcomp, p, X))
                Mcomp === Mcan && isapprox(MM, p, log(MM, p, q), log(Mcomp, p, q))
                Mcomp === Mcan &&
                    isapprox(MM, p, log_lbfgs(MM, p, q), log(Mcomp, p, q), atol=1e-6)
                lbfgs_options = Dict([
                    ("complementary_rank_cutoff", 1.5e-14),
                    ("corrections", 5),
                    ("c1", 1.1e-4),
                    ("c2", 0.9),
                    ("max_ls", 20),
                    ("max_fun_evals", 1500),
                ])

                Mcomp === Mcan && isapprox(
                    MM,
                    p,
                    log_lbfgs(MM, p, q, lbfgs_options=lbfgs_options),
                    log(Mcomp, p, q),
                    atol=1e-6,
                )

                @test isapprox(MM, exp(MM, p, 0 * X), p)
                @test isapprox(MM, p, log(MM, p, p), zero_vector(MM, p); atol=1e-6)
                @test isapprox(MM, p, log_lbfgs(MM, p, p), zero_vector(MM, p); atol=1e-6)
            end
            @testset "α=$α" for α in [-0.75, -0.25, 0.5]
                MM = MetricManifold(M, StiefelSubmersionMetric(α))
                p = project(MM, randn(representation_size(M)))
                X = project(MM, p, randn(representation_size(M)))
                X ./= norm(MM, p, X)
                q = exp(MM, p, X)
                @test is_point(MM, q)
                @test isapprox(MM, p, log(MM, p, q), X)
                @test isapprox(MM, p, Manifolds.log_lbfgs(MM, p, q), X, atol=1e-6)

                @test isapprox(MM, exp(MM, p, 0 * X), p)
                @test isapprox(MM, p, log(MM, p, p), zero_vector(MM, p); atol=1e-6)
                @test isapprox(MM, p, log_lbfgs(MM, p, p), zero_vector(MM, p); atol=1e-6)
            end
        end
    end
end
