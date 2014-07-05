#|
  This file is a part of cl-voxelize project.
  Copyright (c) 2014 Masayuki Takagi (kamonama@gmail.com)
|#

(in-package :cl-user)
(defpackage cl-voxelize
  (:use :cl)
  (:export :voxelize)
  (:import-from :alexandria
                :curry))
(in-package :cl-voxelize)


;;;
;;; Triangles
;;;

(defun triangles-bounding-box (triangles)
  (let ((boxes (mapcar #'triangle-bounding-box triangles)))
    (let (xs0 ys0 zs0 xs1 ys1 zs1)
      (loop for (x0 y0 z0 x1 y1 z1) in boxes
         do (push x0 xs0)
            (push y0 ys0)
            (push z0 zs0)
            (push x1 xs1)
            (push y1 ys1)
            (push z1 zs1))
      (list (apply #'min xs0)
            (apply #'min ys0)
            (apply #'min zs0)
            (apply #'max xs1)
            (apply #'max ys1)
            (apply #'max zs1)))))


;;;
;;; Triangle
;;;

(defmacro with-triangle (((x0 y0 z0)
                          (x1 y1 z1)
                          (x2 y2 z2)) triangle &body body)
  `(destructuring-bind ((,x0 ,y0 ,z0)
                        (,x1 ,y1 ,z1)
                        (,x2 ,y2 ,z2)) ,triangle
     ,@body))

(defun triangle-bounding-box (triangle)
  (with-triangle ((x0 y0 z0)
                  (x1 y1 z1)
                  (x2 y2 z2)) triangle
    (list (min x0 x1 x2)
          (min y0 y1 y2)
          (min z0 z1 z2)
          (max x0 x1 x2)
          (max y0 y1 y2)
          (max z0 z1 z2))))


;;;
;;; Quadtree
;;;

(defstruct (quadtree (:constructor %make-quadtree))
  triangles
  nw ne sw se
  boundary
  depth)

(defvar *max-depth* 2)

(defvar *max-capacity* 8)

(defun %empty-quadtree (x0 y0 x1 y1 depth)
  (declare (float x0 y0 x1 y1))
  (unless (<= 0 depth *max-depth*)
    (error "The value ~S is an invalid depth." depth))
  (%make-quadtree :boundary (list x0 y0 x1 y1)
                  :depth depth))

(defun empty-quadtree (x0 y0 x1 y1)
  (%empty-quadtree x0 y0 x1 y1 0))

(defun quadtree-node-p (quadtree)
  (and (quadtree-nw quadtree)
       t))

(defun quadtree-leaf-p (quadtree)
  (not (quadtree-node-p quadtree)))

(defun quadtree-max-depth-p (quadtree)
  (= (quadtree-depth quadtree) *max-depth*))

(defun quadtree-max-capacity-p (quadtree)
  (= (length (quadtree-triangles quadtree)) *max-capacity*))

(defun quadtree-root-p (quadtree)
  (= (quadtree-depth quadtree) 0))

(defun devide-quadtree (quadtree)
  (unless (quadtree-leaf-p quadtree)
    (error "The quadtree ~A must be a leaf to be devided." quadtree))
  (destructuring-bind (x0 y0 x1 y1) (quadtree-boundary quadtree)
    (let ((xmid (/ (- x1 x0) 2.0))
          (ymid (/ (- y1 y0) 2.0))
          (depth (1+ (quadtree-depth quadtree))))
      (setf (quadtree-nw quadtree) (%empty-quadtree x0 ymid xmid y1 depth)
            (quadtree-ne quadtree) (%empty-quadtree xmid ymid x1 y1 depth)
            (quadtree-sw quadtree) (%empty-quadtree x0 y0 xmid ymid depth)
            (quadtree-se quadtree) (%empty-quadtree xmid y0 x1 ymid depth))
      (loop while (quadtree-triangles quadtree)
         do (let ((triangle (pop (quadtree-triangles quadtree))))
              (insert-quadtree (quadtree-nw quadtree) triangle)
              (insert-quadtree (quadtree-ne quadtree) triangle)
              (insert-quadtree (quadtree-sw quadtree) triangle)
              (insert-quadtree (quadtree-se quadtree) triangle))))))

;; (defun triangle-small-enough-p (quadtree triangle)
;;   (destructuring-bind (x0 y0 x1 y1) (quadtree-boundary quadtree)
;;     (let ((criteria-x (/ (- x1 x0) (expt 2 *max-depth*) 2))
;;           (criteria-y (/ (- y1 y0) (expt 2 *max-depth*) 2)))
;;       (destructuring-bind (tx0 ty0 tz0 tx1 ty1 tz1)
;;           (triangle-bounding-box triangle)
;;         (declare (ignore tz0 tz1))
;;         (and (<= (- tx1 tx0) criteria-x)
;;              (<= (- ty1 ty0) criteria-y))))))

(defun triangle-intersect-p (boundary triangle)
  (destructuring-bind (x0 y0 x1 y1) boundary
    (destructuring-bind (tx0 ty0 tz0 tx1 ty1 tz1)
        (triangle-bounding-box triangle)
      (declare (ignore tz0 tz1))
      (and (or (<= x0 tx0 x1) (<= x0 tx1 x1) (<= tx0 x0 x1 tx1))
           (or (<= y0 ty0 y1) (<= y0 ty1 y1) (<= ty0 y0 y1 ty1))))))

(defun or! (&rest args)
  ;; same as OR except that OR! is eager, not short-circuit, evaluation
  (some #'identity args))

(defun insert-quadtree (quadtree triangle)
;;   (unless (triangle-small-enough-p quadtree triangle)
;;     (warn "The triangle ~A is not small enough." triangle))
  (cond
    ((not (triangle-intersect-p (quadtree-boundary quadtree) triangle))
     nil)
    ((quadtree-node-p quadtree)
     (or! (insert-quadtree (quadtree-nw quadtree) triangle)
          (insert-quadtree (quadtree-ne quadtree) triangle)
          (insert-quadtree (quadtree-sw quadtree) triangle)
          (insert-quadtree (quadtree-se quadtree) triangle)))
    ((quadtree-leaf-p quadtree)
     (cond
       ((quadtree-max-depth-p quadtree)
        (push triangle (quadtree-triangles quadtree))
        t)
       ((not (quadtree-max-capacity-p quadtree))
        (push triangle (quadtree-triangles quadtree))
        t)
       (t
        ;; devide quadtree
        (devide-quadtree quadtree)
        ;; try to insert again
        (insert-quadtree quadtree triangle))))))

(defun quadtree (triangles)
  (destructuring-bind (x0 y0 z0 x1 y1 z1)
      (triangles-bounding-box triangles)
    (declare (ignore z0 z1))
    (let ((qt (empty-quadtree x0 y0 x1 y1)))
      (loop for triangle in triangles
         do (insert-quadtree qt triangle))
      qt)))

(defun point-intersect-p (boundary x y)
  (destructuring-bind (x0 y0 x1 y1) boundary
    (and (<= x0 x x1)
         (<= y0 y y1))))

(defun query-quadtree (quadtree x y)
  (declare (float x y))
  (cond
    ((not (point-intersect-p (quadtree-boundary quadtree) x y))
     nil)
    ((quadtree-node-p quadtree)
     ;; assured that just one of four sub-trees sould handle point (x, y)
     (or (query-quadtree (quadtree-nw quadtree) x y)
         (query-quadtree (quadtree-ne quadtree) x y)
         (query-quadtree (quadtree-sw quadtree) x y)
         (query-quadtree (quadtree-se quadtree) x y)))
    ((quadtree-leaf-p quadtree)
     (quadtree-triangles quadtree))))


;;;
;;; Voxelize
;;;

(defun intersection-z (x y triangle)
  (with-triangle ((x0 y0 z0)
                  (x1 y1 z1)
                  (x2 y2 z2)) triangle
    (let ((xx0 (- x x0))
          (x10 (- x1 x0))
          (x20 (- x2 x0))
          (yy0 (- y y0))
          (y10 (- y1 y0))
          (y20 (- y2 y0))
          (z10 (- z1 z0))
          (z20 (- z2 z0)))
      (let* ((d (- (* x10 y20) (* x20 y10)))
             (s (/ (- (* y20 xx0) (* x20 yy0)) d))
             (%t (/ (- (* x10 yy0) (* y10 xx0)) d)))
        (let ((z (+ z0 (* s z10) (* %t z20))))
          (if (and (<= 0.0 s) (<= 0.0 %t) (<= (+ s %t) 1.0))
              z
              nil))))))

(defun inside-p (x y z triangles)
  (oddp
    (length
      (remove-if-not (curry #'> z)
        (remove-duplicates
          (remove nil
            (mapcar (curry #'intersection-z x y)
              triangles)))))))

(defun voxelize (triangles delta)
  (let ((qt (quadtree triangles))
        (delta2 (/ delta 2.0)))
    (let (ret)
      (destructuring-bind (x0 y0 z0 x1 y1 z1)
          (triangles-bounding-box triangles)
        (loop for y = (+ y0 delta2) then (+ y delta) while (< y y1) do
          (loop for x = (+ x0 delta2) then (+ x delta) while (< x x1)
             do (let ((triangles0 (query-quadtree qt x y)))
                  (loop for z = (+ z0 delta2) then (+ z delta) while (< z z1)
                     if (inside-p x y z triangles0)
                     do (push (list x y z) ret))))))
      ret)))
